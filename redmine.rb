#!/usr/bin/ruby

require 'rubygems'
require 'mechanize'
require 'csv'
require 'config'

LOGIN_URL = "/login"
TIMELOG_URL = "/timelog/edit?issue_id="

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

redmine = Redmine.new(REDMINE_URL, USERNAME, PASSWORD)
redmine.login
file = File.new(CSV_FILE, 'rb')
csv = CSV::Reader.parse(file) do |row|
  begin
    redmine.timelog(row[1], row[0], row[2])
  rescue Exception
    print "ERROR: #{row.join ','}"
    raise
  end
end
