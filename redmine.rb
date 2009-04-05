#!/usr/bin/ruby

require 'rubygems'
require 'mechanize'
require 'csv'
require 'yaml'

CONFIG_FILE = "config.yml"
LOGIN_URL = "/login"
TIMELOG_URL = "/timelog/edit?issue_id="
DATE_FORMAT = '%d/%m/%y'

class Redmine
  def initialize(url, username, password)
    @url = url
    @username = username
    @password = password
    @mech = WWW::Mechanize.new
  end

  def login
    @mech.get @url + LOGIN_URL
    form = @mech.page.forms[1]
    form.username = @username
    form.password = @password
    form.click_button
  end

  def timelog(issue, date, time)
    @mech.get @url + TIMELOG_URL + issue
    form = @mech.page.forms[1]
    form.field_with(:name => 'time_entry[spent_on]').value = date
    form.field_with(:name => 'time_entry[hours]').value = time
    form.click_button
  end
end

def parse_time(time)
  if time =~ /^([0-9]+:[0-9]+):/
    $1
  else
    time
  end
end

def parse_date(date)
  begin
    Date.strptime(date, DATE_FORMAT).to_s
  rescue ArgumentError
    date
  end
end

config = open(CONFIG_FILE) { |file| YAML.load(file) }
redmine = Redmine.new(config['redmine_url'], config['username'],
                      config['password'])
redmine.login
file = File.new(config['csv_file'], 'rb')
csv = CSV::Reader.parse(file) do |row|
  begin
    redmine.timelog row[1], parse_date(row[0]), parse_time(row[2])
  rescue Exception
    print "ERROR: #{row.join ','}"
    raise
  end
end
