#!/usr/bin/ruby

# José M. Prieto <jmprieto@gmx.net> wrote this file. As long as you retain
# this notice you can do whatever you want with this stuff. If we meet some
# day, and you think this stuff is worth it, you can buy me a beer in return.

require 'test/unit'
require File.dirname(__FILE__) + '/../redmine'

class RedmineSpy
  attr_reader :invocations

  def initialize()
    @invocations = []
  end

  private
  def method_missing(method, *args, &block)
    @invocations << args.unshift(method)
  end
end

class FunctionalTests < Test::Unit::TestCase
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
  end

  def test_parsing
    parser = RowParser.new @config['replace'], @config['ignore']
    redmine = RedmineSpy.new
    Object.send :parse, @rows, parser, redmine
    assert_equal [
      [:login],
      [:timelog, '27',          '2009-04-10', '12:58'],
      [:timelog, 'not ignore:', '2009-04-11', '16:01'],
      [:timelog, '13',          '2009-04-12', '15:00']
    ], redmine.invocations
  end

  def capture
    stdout = $stdout
    $stdout = StringIO.new
    begin
      yield
    ensure
      out = $stdout.string
      $stdout = stdout
      return out
    end
  end

  def test_dry_run
    out = capture { Object.send :run, @rows, @config, { 'dry-run' => true} }
    expected = <<EOF
2009-04-10,27,12:58
2009-04-11,not ignore:,16:01
2009-04-12,13,15:00
EOF
    assert_equal expected, out
  end
end
