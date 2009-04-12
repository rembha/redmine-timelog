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

class Row
  def initialize(row, replaces, ignores)
    @row = row
    @replaces = replaces
    @ignores = ignores
  end

  def time
    if @row[2] =~ /^([0-9]+:[0-9]+):/
      $1
    else
      @row[2]
    end
  end

  def date
    Date.strptime(@row[0], DATE_FORMAT).to_s
  rescue ArgumentError
    @row[0]
  end

  def task
    if @replaces
      @replaces.each do |key, value|
        if key =~ /^\/.*\/$/ and @row[1].match(key[1..-2]) or @row[1] == key
          return eval value.to_s
        end
      end
    end
    @row[1]
  end

  def ignored?
    if @ignores
      @ignores.each do |ignore|
        if ignore =~ /^\/.*\/$/ and @row[1].match(ignore[1..-2]) or @row[1] == ignore
          return true
        end
      end
    end
    false
  end
end

config = open(CONFIG_FILE) { |file| YAML.load(file) }
redmine = Redmine.new config['redmine']['url'], config['redmine']['username'],
                      config['redmine']['password']
redmine.login
file = File.new config['csv_file'], 'rb'
csv = CSV::Reader.parse(file) do |row|
  begin
    entry = Row.new row, config['replace'], config['ignore']
    if not entry.ignored?
      redmine.timelog entry.task, entry.date, entry.time
    end
  rescue Exception
    print "ERROR: #{row.join ','}"
    raise
  end
end
