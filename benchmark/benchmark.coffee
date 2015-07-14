fs = require 'fs'
path = require 'path'

{filter, match} = require '../src/fuzzaldrin'

lines = fs.readFileSync(path.join(__dirname, 'data.txt'), 'utf8').trim().split('\n')

startTime = Date.now()
results = filter(lines, 'index')
console.log("Filtering #{lines.length} entries for 'index' took #{Date.now() - startTime}ms for #{results.length} results")

startTime = Date.now()
results2 = filter(lines, 'index', {legacy:true})
console.log("Filtering #{lines.length} entries for 'index' took #{Date.now() - startTime}ms for #{results2.length} results (Legacy method)")


startTime = Date.now()
match(line, 'index') for line in lines
console.log("Matching #{lines.length} entries for 'index' took #{Date.now() - startTime}ms for #{results.length} results")

if results.length isnt 6168
  console.error("Results count changed! #{results.length} instead of 6168")
  process.exit(1)
