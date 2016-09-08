require 'net/http'
require 'json'
require 'erb'
require 'cgi'
require 'htmlentities'
require 'ruby-progressbar'

def basis_url
  'https://esrlabs.atlassian.net/wiki/rest/api/'
end


def uri_for_search(name)
  URI(basis_url + "content/search?cql=title=#{name}")
end

def uri_for_content_by_id(id)
  URI(basis_url + "content/#{id}?expand=body.storage")
end

def add_skills(current_skills, all_skills, increment)
  current_skills.each do |skill|
    value = 0
    if all_skills.has_key?(skill)
      value = all_skills[skill]
    end
    all_skills[skill] = value + increment
  end
end

def parse_skills(all_skills, skills, regexp, increment)
  add_skills(skills.scan(regexp).flatten, all_skills, increment)
end

def get_skill_regexp(string)
  if string.length > 0
    string = "aui-lozenge-#{string} "
  end
  Regexp.new("<span class=\"status-macro aui-lozenge #{string}conf-macro output-inline\">(.+?)<\/spa")
end

uri = uri_for_search('NewEmployees')
Net::HTTP.start(
  uri.host,
  uri.port,
  :use_ssl => uri.scheme == 'https') do |http|

  uri = uri_for_search('NewEmployees')
  # get NewEmployee confluence id
  request = Net::HTTP::Get.new(uri.request_uri)
  request.basic_auth('praktikum', 'LOGaBOuS')

  response = http.request(request)

  json = JSON.parse(response.body)
  confluence_id = json['results'].first['id']

  # get NewEmployee content
  uri = uri_for_content_by_id(confluence_id)
  request = Net::HTTP::Get.new(uri.request_uri)
  request.basic_auth('praktikum', 'LOGaBOuS')

  response = http.request(request)

  json = JSON.parse(response.body)
  content = json['body']['storage']['value']

  htmlentities = HTMLEntities.new
  names = content.scan(/<ri:page ri:content-title="(.+?)" \/>/).flatten.map {|i|htmlentities.decode(i)}

  progressbar = ProgressBar.create(total: names.size,
                                   format: "%e %b\u{15E7}%i %j%% %t",
                                   progress_mark: ' ',
                                   remainder_mark: "\u{FF65}",
                                   starting_at: 0)

  all_skills = {}

  names.each do |user|
    begin
      progressbar.title = "working on #{user}".ljust(40)
      progressbar.increment

      uri = uri_for_search('"' + URI.escape(user) + '"')
      request = Net::HTTP::Get.new(uri.request_uri)
      request.basic_auth('praktikum', 'LOGaBOuS')

      response = http.request(request)

      json = JSON.parse(response.body)
      user_id = json['results'].first['id']

      uri = uri_for_content_by_id(user_id)
      request = Net::HTTP::Get.new(uri.request_uri)
      request.basic_auth('praktikum', 'LOGaBOuS')

      response = http.request(request)

      json = JSON.parse(response.body)
      content = json['body']['storage']['value']
      start_index = content.index('Skills')
      raise 'Skills start not found' if start_index == nil

      end_index = content.index('Current Project')
      raise 'Skills end not found' if end_index == nil

      skills = content[start_index..end_index]

      parse_skills(all_skills, skills, get_skill_regexp(''), 1)
      parse_skills(all_skills, skills, get_skill_regexp('current'), 2)
      parse_skills(all_skills, skills, get_skill_regexp('success'), 3)
      parse_skills(all_skills, skills, get_skill_regexp('complete'), 4)
      parse_skills(all_skills, skills, get_skill_regexp('error'), 5)
    rescue StandardError => e
      e.backtrace
      puts "problems with #{user}: #{e.message}"
    end
  end

  skills_as_json = all_skills.map {|key, value|
    "{id: \"#{key}\", value: #{value}}"
  }.join(", ")
  template = ERB.new(File.read('index.html.erb'))
  File.write('index.html', template.result(binding()))

end
