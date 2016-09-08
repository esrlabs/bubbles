require 'net/http'
require 'json'
require 'erb'
require 'cgi'
require 'htmlentities'

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


skills = {"RUST"=>9, "MACOSX"=>2, "TRACE32"=>49, "LINUX"=>40, "VIM"=>24, "C/C++"=>62, "PYTHON"=>25, "BAKE"=>4, "JAVA"=>36, "RUBY"=>38, "KLOCWORK"=>2, "GIT"=>39, "FAT/DS/DM"=>5, "CANOE"=>14, "ASPICE"=>2, "PDX"=>2, "C"=>29, "QT"=>6, "ETHERNET"=>20, "LWIP"=>3, "ECLIPSE"=>14, "ORGANIZE"=>3, "C++"=>40, "WINDOWS"=>12, "DIAGNOSIS"=>9, "KICKER"=>19, "VECTOR"=>2, "RF"=>8, "LAB/HW"=>3, "OSCI/LOGIC"=>10, "SPI/RS232"=>3, "DOORS"=>5, "EXCEL/VBA"=>6, "ADMIN"=>5, "BUILD/JENKINS"=>5, "VIDEO EDIT"=>5, "F#"=>2, "GROOVY"=>2, "(X) EMACS"=>3, "AUTOSAR"=>19, "CMAKE"=>11, "GOLANG"=>2, "FLASK"=>2, "PARTICLE-FILTER"=>2, "LINUXOS"=>3, "KALMAN-FILTER"=>3, "NAVIGATION"=>8, "DOCKER-RKT"=>3, "RPM-PKG"=>3, "DEADRECKONING"=>3, "WAF-BUILDSYSTEM"=>5, "ALGORITHMS"=>3, "NUMBER THEORY"=>3, "DATA STRUCTURE"=>5, "BOOLEAN ALGEBRA"=>5, "ERIKA OS"=>1, "ASM"=>2, "TESTING"=>6, "WIKI"=>8, "DEBUGGING"=>3, "GCC"=>6, "BDC2015 LIGHTEXT"=>3, "BDC2015 LIGHTINT"=>3, "ESYS"=>13, "BMW TOOLS"=>8, "OS X"=>11, "MATLAB"=>7, "ENERGY EFFICIENT SOFTWARE"=>2, "BDC 2015 (LIGHTINT)"=>2, "BDC 2015 (LIGHTEXT)"=>2, "C#"=>11, "LIN"=>12, "CLOJURE"=>2, "LUA"=>5, "JAVASCRIPT"=>10, "CLION"=>2, "SVN"=>7, "HTTP"=>3, "DOIP"=>6, "FLEXRAY"=>8, "CAN"=>18, "UDS"=>8, "TP"=>3, "TCP/IP"=>6, "EXCEL"=>11, "TEMPLATE META PROGRAMMING"=>3, "FLASHING (BMW)"=>5, "HSFZ"=>8, "HW"=>5, "FIBEX"=>5, "WEB"=>9, "LOWLEVEL"=>3, "MODELSTUFF"=>8, "CODEGEN"=>8, "NFC"=>4, "PATTERN RECOGNITION"=>3, "ETH"=>1, "MOST"=>5, "FAS"=>3, "BMW HMI"=>5, "R"=>4, "SSL/TLS"=>4, "WSN"=>9, "SCALA"=>6, "OSEK"=>6, "NETWORKS"=>11, "COM"=>3, "LIFECYCLE"=>3, "BSW"=>3, "GRADLE"=>4, "ESYS / FAT"=>3, "DS, DM"=>3, "WIN32 API"=>3, "BLUETOOTH"=>3, "ANDROID"=>6, "PERFORCE"=>3, "EMACS"=>1, "MAKE"=>1, "D"=>1, "DIAGNOSTICS"=>3, "OSCI"=>3, "WAKE-UP RECEIVER"=>3, "FUSI"=>3, "POWERPOINT"=>3, "KPM-WEB"=>5, "JIRA"=>7, "TRACE 32"=>6, "FAT"=>2, "ODIS"=>5, "TDF"=>2, "VS"=>2, "DIAGNOSE"=>3, "DM"=>3, "FZM"=>3, "CAPL"=>3, "PERL"=>3, "ELECTRONICS"=>1, ".NET ( C#, WPF )"=>3, "WINDOWS API"=>3, "PLUGINS"=>5, "IPTV"=>5, "ODX"=>2, "PROTOBUF"=>3, "DESIGN"=>2, "INTERVIEW"=>3, "TESTS"=>5, "DOORS/DXL"=>2, "C2X"=>3, "MS PROJECT"=>3, "SQL"=>3, "MERCURIAL"=>3, "PROJECT MANAGEMENT"=>5, "KPMWEB"=>4, "COORDINATION"=>2, "IDEX"=>3, "TRACE ANALYSE"=>3, "AUTOMOTIVE ENGINEERING"=>3, "HOW TO @ AUDI"=>3, "PROJECTMANAGEMENT"=>3, "EMBEDDED"=>2, "TYPESCRIPT"=>3, "DATA FOCUSSED"=>3, "LOTS MORE"=>3, "JEE"=>3, "DISTRIBUTED"=>3, "BIG DATA"=>3, "FULL STACK"=>3, "MAVEN"=>5, "SCONS"=>3, "CORTEX M"=>2, "MACHINE LEARNING"=>2, "SIMULINK"=>5}
skills_as_json = skills.map {|key, value|
  "{name: \"#{key}\", size: #{value}, className: \"#{key}\"}"
}.join(", ")
puts skills_as_json


template = ERB.new(File.read('index.js.erb'))
File.write('js/index.js', template.result(binding()))

exit

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

  all_skills = {}

  names.each do |user|
    begin
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
      beginner_skills = skills.scan(/<span class="status-macro aui-lozenge conf-macro output-inline">(.+?)<\/span>/).flatten
      add_skills(beginner_skills, all_skills, 1)

      basic_skills = skills.scan(/<span class="status-macro aui-lozenge aui-lozenge-current conf-macro output-inline">(.+?)<\/span>/).flatten
      add_skills(basic_skills, all_skills, 2)

      intermediate_skills = skills.scan(/<span class="status-macro aui-lozenge aui-lozenge-success conf-macro output-inline">(.+?)<\/span>/).flatten
      add_skills(intermediate_skills, all_skills, 3)

      complete_skills = skills.scan(Regexp.new('<span class="status-macro aui-lozenge aui-lozenge-complete conf-macro output-inline">(.+?)</span>')).flatten
      add_skills(complete_skills, all_skills, 3)

      expert_skills = skills.scan(/<span class="status-macro aui-lozenge aui-lozenge-error conf-macro output-inline">(.+?)<\/span>/).flatten
      add_skills(expert_skills, all_skills, 5)

      puts  "-" * 50
      puts all_skills
    rescue => e
      puts "problems with #{user}: #{e.message}"
    end
  end

  #template = ERB.new(File.read('index.js.erb'))
  #File.write('index.js', template.result(binding()))

end
