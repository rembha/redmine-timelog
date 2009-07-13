#!/usr/bin/ruby

# José M. Prieto <jmprieto@gmx.net> wrote this file. As long as you retain
# this notice you can do whatever you want with this stuff. If we meet some
# day, and you think this stuff is worth it, you can buy me a beer in return.

require 'test/unit'
require File.dirname(__FILE__) + '/../redmine'

class RowParserUnitTests < Test::Unit::TestCase
  def setup
    @config = {
      'replace'  => {
        '/.*#([0-9]+)/' => '$1',
        'thirteen'      => 13
      },
      'ignore'   => [
        'none',
        '/^ignore:/'
      ]
    }
    @rows = [
      ['10/04/09',   '#27: fix bug', nil, nil, nil, '12:58:43'],
      ['11/04/09',   'not ignore:',  nil, nil, nil, '16:01:00'],
      ['2009-04-12', 'thirteen',     nil, nil, nil, '15:00'],
      ['2009-04-13', 'none',         nil, nil, nil, '08:23'],
      ['2009-04-13', 'ignore: test', nil, nil, nil, '09:36:20']
    ]
    @entry = RowParser.new @config['replace'], @config['ignore']
  end

  def test_should_not_crash_if_ignore_is_not_present
    entry = RowParser.new @config['replace'], nil
    assert_nothing_raised do
      entry.row = ['date', 'task', 'time']
      entry.ignored?
    end
  end

  def test_should_not_crash_if_replace_is_not_present
    entry = RowParser.new nil, @config['ignore']
    assert_nothing_raised do
      entry.row = ['date', 'task', 'time']
      entry.ignored?
    end
  end

  def test_should_ignore_some_rows
    result = @rows.collect do |row|
      @entry.row = row
      @entry.ignored?
    end
    assert_equal [false, false, false, true, true], result
  end

  def test_should_parse_dates
    result = @rows.collect do |row|
      @entry.row = row
      @entry.date
    end
    assert_equal ['2009-04-10', '2009-04-11', '2009-04-12', '2009-04-13',
                  '2009-04-13'], result
  end

  def test_should_parse_times
    result = @rows.collect do |row|
      @entry.row = row
      @entry.time
    end
    assert_equal ['12:58', '16:01', '15:00', '08:23', '09:36'], result
  end

  def test_should_replace_some_rows
    result = @rows.collect do |row|
      @entry.row = row
      @entry.task
    end
    assert_equal ['27', 'not ignore:', '13', 'none', 'ignore: test'], result
  end
end
