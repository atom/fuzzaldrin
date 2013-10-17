# fuzzaldrin

String scoring and filtering

## Using

```sh
npm install fuzzaldrin
```

```coffee
{filter, score} = require 'fuzzaldrin'

filter(['Call', 'Me', 'Maybe'], 'me') # ['Me', 'Maybe']

score('Me', 'me') # 0.75
score('Maybe', 'me') # 0.31499999999999995
```
