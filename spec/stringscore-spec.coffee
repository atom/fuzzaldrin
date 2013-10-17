score = require '../vendor/stringscore'

describe "stringscore", ->
  it "returns a score", ->
    expect(score('Hello World', 'he')).toBeLessThan(score('Hello World', 'Hello'))
    expect(score('Hello World', 'Hello World')).toBe 1
    expect(score('Hello World', '')).toBe 0
