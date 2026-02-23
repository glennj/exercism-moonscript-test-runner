#! /usr/bin/env moon

-- Implements test-runner interface version 2

require 'moonscript'
lfs = require 'lfs'
json = (require 'dkjson').use_lpeg!
getopt = require 'alt_getopt'
local verbose

import p from require 'moon'


-- -----------------------------------------------------------
show_help = (args) ->
  print "Usage: #{args[0]} [-h] [-v]  slug  solution-dir  output-dir"
  print "Where: -h   show this help"
  print "       -v   verbose: show the output JSON"
  os.exit!


-- -----------------------------------------------------------
file_exists = (path) ->
  attrs = lfs.attributes path
  not not attrs

is_directory = (path) ->
  attrs = lfs.attributes path
  attrs and attrs.mode == 'directory'

realpath = (path) ->
  fh = io.popen "realpath #{path}"
  dir = fh\read!
  fh\close!
  dir

validate = (args) ->
  show_help args unless #args == 3
  {slug, src_dir, dest_dir} = args
  assert slug != '', 'First arg, the slug, cannot be empty'
  assert is_directory(src_dir), 'Second arg, the solution directory, must be a directory'
  assert is_directory(dest_dir), 'Third arg, the output directory, must be a directory'

  slug, realpath(src_dir), realpath(dest_dir)


-- -----------------------------------------------------------
run_tests = (slug, dir) ->
  ok, err = lfs.chdir dir
  assert ok, err

  -- unskip tests
  cmd = "perl -i.bak -pe 's{^\\s*\\Kpending\\b}{it}' *_spec.moon"
  ok, result_type, status = os.execute cmd
  assert ok

  -- launch `busted`
  fh = io.popen 'busted -o json', 'r'
  json_output = fh\read 'a'
  ok, exit_type, exit_status = fh\close!

  if exit_type == 'signal'
    return {
      status: 'error',
      message: json_output
    }

  data = json.decode json_output

  if not data
    output = json_output

    if output\match "^Failed to encode test results to json"
      -- This is a syntax error: moon can't compile it.
      -- Busted cannot output JSON results.
      -- Grab the output from vanilla busted.
      fh = io.popen 'busted', 'r'
      output = fh\read 'a'
      fh\close!
      -- trim off some non-determinant output
      output = output\gsub " : [%d.]+ seconds", ""

    return {
      status: 'error',
      message: output
    }


  if exit_status != 0 and #data.successes == 0 and #data.failures == 0 and #data.errors > 0
    return {
      status: 'error',
      message: data.errors[1].message
    }

  results = {}

  for test in *data.successes
    results[test.element.name] = {
      status: 'pass',
      name: test.element.name,
    }

  for test in *data.failures
    results[test.element.name] = {
      status: 'fail',
      name: test.element.name,
      message: test.trace.message,
    }

  for test in *data.errors
    results[test.element.name] = {
      status: 'error',
      name: test.element.name,
      message: test.trace.message,
    }

  results


-- -----------------------------------------------------------
get_test_bodies = (slug, dir) ->
  ok, err = lfs.chdir dir
  assert ok, err

  order = {}
  bodies = {}

  test_file = "#{slug\gsub('-', '_')}_spec.moon"
  return unless file_exists test_file -- let `busted` handle the error messaging

  fh = io.open test_file, 'r'

  pattern = (word) -> '^%s+' .. word .. '%s+[\'"](.+)[\'"],%s+->'
  patterns = it: pattern('it'), pending: pattern('pending')

  local test_name
  test_body = {}
  in_test = false

  for line in fh\lines!
    if line\match '^%s+describe '
      if test_name
        bodies[test_name] = table.concat test_body, '\n'
        test_body = {}
        test_name = nil
      in_test = false

    m = line\match(patterns.it) or line\match(patterns.pending)
    if not m
      if in_test
        table.insert test_body, line
    else
      table.insert order, m
      if in_test
        bodies[test_name] = table.concat test_body, '\n'
        test_body = {}
      test_name = m
      in_test = true

  fh\close!
  bodies[test_name] = table.concat test_body, '\n'
  order, bodies


-- -----------------------------------------------------------
write_results = (slug, test_results, names, bodies, dir) ->
  ok, err = lfs.chdir dir
  assert ok, "#{err}: #{dir}"
  
  results = version: 2, status: nil, tests: {}

  if test_results.status
    -- this was an error result
    results.status = test_results.status
    results.message = test_results.message

  else
    status = 'pass'
    for name in *names
      test = test_results[name]
      assert test, "no test result for #{name}"
      status = 'fail' if test.status != 'pass'
      test.test_code = bodies[name]
      table.insert results.tests, test
    results.status = status

  fh = io.open 'results.json', 'w'
  fh\write (json.encode results) .. '\n'
  fh\close!

  os.execute "jq . results.json" if verbose


-- -----------------------------------------------------------
main = (args) ->
  opts, optind = getopt.get_opts args, 'hv', {}

  show_help args if opts.h
  verbose = not not opts.v
  table.remove args, 1 for _ = 1, optind - 1

  slug, src_dir, dest_dir = validate args

  print "#{slug}: testing ..."

  test_names_ordered, test_code = get_test_bodies slug, src_dir

  test_results = run_tests slug, src_dir

  write_results slug, test_results, test_names_ordered, test_code, dest_dir

  print "#{slug}: ... done"

main arg
