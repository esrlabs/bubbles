require 'net/http'
require 'json'
require 'erb'
require 'cgi'
require 'htmlentities'
require 'ruby-progressbar'
require 'values'
require 'byebug'

def basis_url
  'https://esrlabs.atlassian.net/wiki/rest/api/'
end

def uri_for_search(name)
  URI(basis_url + "content/search?cql=title=#{name}")
end

def uri_for_content_by_id(id)
  URI(basis_url + "content/#{id}?expand=body.storage")
end

def add_skills(current_skills, all_skills, employee, level)
  current_skills.each do |name|
    name.capitalize!
    skill = Skill.new(name, level)
    employee.add_skill(skill)
    value = 0
    if all_skills.has_key?(name)
      value = all_skills[name]
    end
    all_skills[name] = value + level
  end
end

def parse_skills(all_skills, employee, skills, regexp, level)
  add_skills(skills.scan(regexp).flatten, all_skills, employee, level)
end

def get_skill_regexp1(string)
  if string.length > 0
    string = "aui-lozenge-#{string} "
  end
  Regexp.new("<span class=\"status-macro aui-lozenge #{string}conf-macro output-inline\">(.+?)<\/spa")
end
def get_skill_regexp2(string)
  Regexp.new("<ac:structured-macro ac:name=\"status\".*?<ac:parameter ac:name=\"colour\">#{string}.*?<ac:parameter ac:name=\"title\">(.*?)</ac:parameter>")
end

class Cache
  require 'yaml'
  def initialize
    begin
      @data = YAML::load_file('.cache')
    rescue
      @data = {}
    end
  end
  def get(uri)
    @data[uri]
  end
  def include?(uri)
    @data.include?(uri)
  end
  def put(uri, data)
    @data[uri] = data
  end
  def store
    File.write('.cache', @data.to_yaml)
  end
end

def get(connection, uri, cache)
  s = uri.request_uri
  if cache.include?(s)
    body = cache.get(s)
  else
    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth('praktikum', File.read('password'))
    response = connection.request(request)
    if response.code != "200"
      raise "could not get #{response.code}"
    end
    body = response.body.to_s
    cache.put(s, body)
  end
  json = JSON.parse(body)
end

class Level
  def initialize(level)
    @level = level
  end
  def self.from_int(i)
    return Level.new(i)
  end
  def to_s
    level_to_string = {1 => 'Beginner',
                       2 => 'Basic',
                       3 => 'Intermediate',
                       4 => 'Advanced',
                       5 => 'Expert'}
    "Level(#{level_to_string[@level]})"
  end
end

Skill = Value.new(:name, :level)

class Employee
  attr_reader :name, :skills
  def initialize(name)
    @name = name
    @skills = {}
  end
  def add_skill(skill)
    @skills[skill.name] = skill
  end
  def level_of(skill)
    @skills[skill].level
  end
  def to_s
    "Employee(#{@name}) [#{@skills.values.join(', ')}]"
  end
end

cache = Cache.new

uri = uri_for_search('NewEmployees')
Net::HTTP.start(
  uri.host,
  uri.port,
  :use_ssl => uri.scheme == 'https') do |http|

  # get NewEmployee confluence id
  json = get(http, uri_for_search('NewEmployees'), cache)
  confluence_id = json['results'].first['id']

  # get NewEmployee content
  json = get(http, uri_for_content_by_id(confluence_id), cache)
  content = json['body']['storage']['value']

  htmlentities = HTMLEntities.new
  names = content.scan(/<ri:page ri:content-title="(.+?)" \/>/).flatten.map {|i|htmlentities.decode(i)}

  progressbar = ProgressBar.create(total: names.size,
                                   format: "%e %b\u{15E7}%i %j%% %t",
                                   progress_mark: ' ',
                                   remainder_mark: "\u{FF65}",
                                   starting_at: 0)
  all_skills = {}
  all_employees = []

  names.each do |name|
    employee = Employee.new(name)
    begin
      #byebug if name.include?('Christian')
      progressbar.title = "working on #{employee.name}".ljust(40)
      progressbar.increment

      json = get(http, uri_for_search('"' + URI.escape(employee.name) + '"'), cache)
      user_id = json['results'].first['id']

      json = get(http, uri_for_content_by_id(user_id), cache)
      content = json['body']['storage']['value']
      start_index = content.index('Skills')
      raise 'Skills start not found' if start_index == nil

      end_index = content.index('Current Project')
      raise 'Skills end not found' if end_index == nil

      skills = content[start_index..end_index]

      parse_skills(all_skills, employee, skills, get_skill_regexp1(''), 1)
      parse_skills(all_skills, employee, skills, get_skill_regexp2('Grey'), 1)

      parse_skills(all_skills, employee, skills, get_skill_regexp1('current'), 2)
      parse_skills(all_skills, employee, skills, get_skill_regexp2('Yellow'), 2)

      parse_skills(all_skills, employee, skills, get_skill_regexp1('success'), 3)
      parse_skills(all_skills, employee, skills, get_skill_regexp2('Green'), 3)

      parse_skills(all_skills, employee, skills, get_skill_regexp1('complete'), 4)
      parse_skills(all_skills, employee, skills, get_skill_regexp2('Blue'), 4)

      parse_skills(all_skills, employee, skills, get_skill_regexp1('error'), 5)
      parse_skills(all_skills, employee, skills, get_skill_regexp2('Red'), 5)
      all_employees << employee
    rescue StandardError => e
      e.backtrace
      STDERR.puts "problems with #{employee}: #{e.message}"
    end
  end

  cache.store
  skills_as_json = all_skills.map {|key, value|
    "{id: \"#{key}\", value: #{value}}"
  }.join(", ")
  template = ERB.new(File.read('index.html.erb'))
  File.write('index.html', template.result(binding()))

  skills = all_employees.inject({}) do |skills, employee|
    employee.skills.each do |name, employee_skills|
      if skills.include?(name)
        skills[name] << employee
      else
        skills[name] = [employee]
      end
    end
    skills
  end
  skills.update(skills) do |skill, old_employees, new_employees|
    new_employees.group_by{|e|e.level_of(skill)}
  end
  template = ERB.new(File.read('skill2employees.html.erb'))
  File.write('skill2employees.html', template.result(binding()))
end
