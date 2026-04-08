utc_time = require 'can_use_lua_tz'

describe 'one test', ->
  it 'test time in UTC', ->
    assert.are.equal 1414872000, utc_time!
