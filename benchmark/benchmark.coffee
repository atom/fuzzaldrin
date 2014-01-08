fs = require 'fs'
path = require 'path'

{filter} = require '../src/fuzzaldrin'

lines = fs.readFileSync(path.join(__dirname, 'data.txt'), 'utf8').trim().split('\n')

startTime = Date.now()
results = filter(lines, 'index')
console.log("Filtering #{lines.length} entries for 'index' took #{Date.now() - startTime}ms for #{results.length} results")

if results.length isnt 514
  console.error("Results count changed! #{results.length} instead of 514")
  process.exit(1)
