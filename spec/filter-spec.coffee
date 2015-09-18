path = require 'path'
{filter,score} = require '../src/fuzzaldrin'

bestMatch = (candidates, query, {debug}={}) ->

  if debug?
    console.log("\n = Against query: #{query} = ")
    console.log(" #{score(c, query)}: #{c}") for c in candidates

  filter(candidates, query, maxResults: 1)[0]

rootPath = (segments...) ->
  joinedPath = if process.platform is 'win32' then 'C:\\' else '/'
  #joinedPath = path.sep
  for segment in segments
    if segment is path.sep
      joinedPath += segment
    else
      joinedPath = path.join(joinedPath, segment)
  joinedPath

describe "filtering", ->

  it "returns an array of the most accurate results", ->
    candidates = ['Gruntfile', 'filter', 'bile', null, '', undefined]
    expect(filter(candidates, 'file')).toEqual ['Gruntfile', 'filter']

  it "require all character to be present", ->
    candidates = ["Application:Hide"]
    expect(filter(candidates, 'help')).toEqual []

  describe "when the maxResults option is set", ->
    it "limits the results to the result size", ->
      candidates = ['Gruntfile', 'filter', 'bile']
      expect(bestMatch(candidates, 'file')).toBe 'Gruntfile'


  #---------------------------------------------------
  #
  #                  Exact match
  #

  describe "when query is an exact match", ->

    it "prefer match at word boundary (string limit)", ->
      candidates = ['0gruntfile0', 'gruntfile0', '0gruntfile']
      expect(bestMatch(candidates, 'file')).toBe candidates[2]
      expect(bestMatch(candidates, 'grunt')).toBe candidates[1]

    it "prefer match at word boundary (separator limit)", ->
      candidates = ['0gruntfile0', 'hello gruntfile0', '0gruntfile world']
      expect(bestMatch(candidates, 'file')).toBe candidates[2]
      expect(bestMatch(candidates, 'grunt')).toBe candidates[1]

    it "prefer match at word boundary (camelCase limit)", ->
      candidates = ['0gruntfile0', 'helloGruntfile0', '0gruntfileWorld']
      expect(bestMatch(candidates, 'file')).toBe candidates[2]
      expect(bestMatch(candidates, 'grunt')).toBe candidates[1]


    it "it ranks full-word > start-of-word > end-of-word > middle-of-word > split > scattered letters", ->

      candidates = [
        'controller',
        '0 co re 00',
        '0core0 000',
        '0core 0000',
        '0 core0 00',
        '0 core 000'
      ]

      result = filter(candidates, 'core')
      expect(result[0]).toBe candidates[5]
      expect(result[1]).toBe candidates[4]
      expect(result[2]).toBe candidates[3]
      expect(result[3]).toBe candidates[2]
      expect(result[4]).toBe candidates[1]
      expect(result[5]).toBe candidates[0]

    it "rank middle of word case-insensitive match better than complete word not quite exact match (sequence length is king)", ->

      candidates = [
        'ZFILEZ',
        'fil e'
      ]

      expect(bestMatch(candidates, 'file')).toBe candidates[0]

    it "prefer smaller haystack", ->

      candidates = [
        'core_',
        'core'
      ]

      expect(bestMatch(candidates, 'core')).toBe candidates[1]


    it "prefer match at the start of the string", ->

      candidates = [
        'data_core',
        'core_data'
      ]

      expect(bestMatch(candidates, 'core')).toBe candidates[1]

      candidates = [
        'hello_data_core',
        'hello_core_data'
      ]

      expect(bestMatch(candidates, 'core')).toBe candidates[1]


  #---------------------------------------------------
  #
  #                  Consecutive letters
  #

  describe "when query match in multiple group", ->

    # string limit, separator limit, camelCase limit
    # reuse the same method as exact match, should that change, insert test here.

    it "it ranks full-word > start-of-word > end-of-word > middle-of-word > scattered letters", ->

      candidates = [
        'model-controller'
        'model-0core0-000'
        'model-0core-0000'
        'model-0-core0-00'
        'model-0-core-000'
      ]

      result = filter(candidates, 'modelcore')
      expect(result[0]).toBe candidates[4]
      expect(result[1]).toBe candidates[3]
      expect(result[2]).toBe candidates[2]
      expect(result[3]).toBe candidates[1]
      expect(result[4]).toBe candidates[0]

    it "it ranks full-word > start-of-word > end-of-word > middle-of-word > scattered letters (VS directory depth)", ->

      candidates = [
        path.join('model', 'controller'),
        path.join('0', 'model', '0core0_0'),
        path.join('0', '0', 'model', '0core_00'),
        path.join('0', '0', '0', 'model', 'core0_00'),
        path.join('0', '0', '0', '0', 'model', 'core_000')
      ]

      result = filter(candidates, 'model core')
      expect(result[0]).toBe candidates[4]
      expect(result[1]).toBe candidates[3]
      expect(result[2]).toBe candidates[2]
      expect(result[3]).toBe candidates[1]
      expect(result[4]).toBe candidates[0]


    it "weighs consecutive character higher than scattered letters", ->

      candidates = [
        'application.rb'
        'application_controller'
      ]
      expect(bestMatch(candidates, 'acon')).toBe candidates[1]

    it "prefer larger group of consecutive letter", ->

      #Here all group score the same context (full word).

      candidates = [
        'ab cd ef',
        ' abc def',
        ' abcd ef',
        ' abcde f',
        '  abcdef'
      ]

      result = filter(candidates, 'abcdef')
      expect(result[0]).toBe candidates[4]
      expect(result[1]).toBe candidates[3]
      expect(result[2]).toBe candidates[2]
      expect(result[3]).toBe candidates[1]
      expect(result[4]).toBe candidates[0]

    it "prefer larger group of consecutive letter VS better context", ->

      #Only apply when EVERY lowe quality context group are longer or equal length

      candidates = [
        'ab cd ef', # 3 x 2
        '0abc0def0' # 2 x 3
      ]

      expect(bestMatch(candidates, 'abcdef')).toBe candidates[1]

      candidates = [
        'ab cd ef', # 2 x 2 + 2
        '0abcd0ef0' # 1 x 4 + 2
      ]

      expect(bestMatch(candidates, 'abcdef')).toBe candidates[1]

    it "allow consecutive character in path overcome deeper path", ->

      candidates = [
        path.join('controller', 'app.rb')
        path.join('controller', 'core', 'app.rb')
      ]
      expect(bestMatch(candidates, 'core app')).toBe candidates[1]

    it "weighs matches at the start of the string or base name higher", ->

      expect(bestMatch(['a_b_c', 'a_b'], 'ab')).toBe 'a_b'
      expect(bestMatch(['z_a_b', 'a_b'], 'ab')).toBe 'a_b'
      expect(bestMatch(['a_b_c', 'c_a_b'], 'ab')).toBe 'a_b_c'


  #---------------------------------------------------
  #
  #                  Acronym + Case Sensitivity
  #

  describe "when the entries contains mixed case", ->

    it "weighs exact case matches higher", ->
      candidates = ['statusurl', 'StatusUrl']
      expect(bestMatch(candidates, 'Status')).toBe 'StatusUrl'
      expect(bestMatch(candidates, 'status')).toBe 'statusurl'
      expect(bestMatch(candidates, 'statusurl')).toBe 'statusurl'
      expect(bestMatch(candidates, 'StatusUrl')).toBe 'StatusUrl'

    it "account for case while selecting an acronym", ->
      candidates = ['statusurl', 'status_url', 'StatusUrl']
      expect(bestMatch(candidates, 'SU')).toBe 'StatusUrl'
      expect(bestMatch(candidates, 'su')).toBe 'status_url'
      expect(bestMatch(candidates, 'st')).toBe 'statusurl'

    it "weighs exact case matches higher", ->

      candidates = ['Diagnostic', 'diagnostics0000']
      expect(bestMatch(candidates, 'diag')).toBe candidates[1]
      expect(bestMatch(candidates, 'diago')).toBe candidates[1]

      candidates = ['download_thread', 'DownloadTask']
      expect(bestMatch(candidates, 'down')).toBe candidates[0]
      expect(bestMatch(candidates, 'downt')).toBe candidates[0]
      expect(bestMatch(candidates, 'downta')).toBe candidates[1]
      expect(bestMatch(candidates, 'dt')).toBe candidates[0]
      expect(bestMatch(candidates, 'DT')).toBe candidates[1]

    it "weighs case sentitive matches higher Vs directory depth", ->

      candidates = [path.join('0', 'Diagnostic'), path.join('0', '0', '0', 'diagnostics00')]
      expect(bestMatch(candidates, 'diag')).toBe candidates[1]
      expect(bestMatch(candidates, 'diago')).toBe candidates[1]


    it "weighs abbreviation matches after spaces, underscores, and dashes the same", ->
      expect(bestMatch(['sub-zero', 'sub zero', 'sub_zero'], 'sz')).toBe 'sub-zero'
      expect(bestMatch(['sub zero', 'sub_zero', 'sub-zero'], 'sz')).toBe 'sub zero'
      expect(bestMatch(['sub_zero', 'sub-zero', 'sub zero'], 'sz')).toBe 'sub_zero'


    it "weighs CamelCase matches higher", ->

      candidates = [
        'FilterFactors.html',
        'FilterFactorTests.html'
      ]

      # Alignment match "t" of factor preventing to score "T" of Test
      expect(bestMatch(candidates, 'FFT')).toBe 'FilterFactorTests.html'

    it "prefer longer acronym to a smaller case sensitive one", ->

      candidates = [
        'efficient'
        'fun fact'
        'FileFactory'
        'FilterFactorTests.html'
      ]

      # fun fact is case-sensitive match for fft, but the t of fact is not an acronym
      expect(bestMatch(candidates, 'fft')).toBe 'FilterFactorTests.html'
      expect(bestMatch(candidates, 'ff')).toBe 'fun fact'
      expect(bestMatch(candidates, 'FF')).toBe 'FileFactory'

    it "weighs acronym matches higher than middle of word exact match", ->

      candidates = [
        'switch.css',
        'ImportanceTableCtrl.js'
      ]
      expect(bestMatch(candidates, 'itc')).toBe candidates[1]
      expect(bestMatch(candidates, 'ITC')).toBe candidates[1]

    it "allow to select between snake_case and CamelCase using case of query", ->

      candidates = [
        'switch.css',
        'user_id_to_client',
        'ImportanceTableCtrl.js'
      ]
      expect(bestMatch(candidates, 'itc')).toBe candidates[1]
      expect(bestMatch(candidates, 'ITC')).toBe candidates[2]


    it "prefer CamelCase that happens sooner", ->

      candidates = [
        'anotherCamelCase',
        'thisCamelCase000',
      ]

      #We test once for exact acronym then for general purpose match.
      expect(bestMatch(candidates, 'CC')).toBe candidates[1]
      expect(bestMatch(candidates, 'CCs')).toBe candidates[1]

    it "prefer CamelCase in shorter haystack", ->

      candidates = [
        'CamelCase0',
        'CamelCase',
      ]
      expect(bestMatch(candidates, 'CC')).toBe candidates[1]
      expect(bestMatch(candidates, 'CCs')).toBe candidates[1]

    it "allow CamelCase to match across words", ->

      candidates = [
        'Gallas',
        'Git Plus: Add All', #skip the Plus, still get bonus.
      ]
      expect(bestMatch(candidates, 'gaa')).toBe candidates[1]

    it "allow CamelCase to match even outside of acronym prefix", ->

      candidates = [
        'Git Plus: Stash Save',
        'Git Plus: Add And Commit',
        'Git Plus: Add All',
      ]

      result = filter(candidates, 'git AA')
      expect(result[0]).toBe candidates[2]
      expect(result[1]).toBe candidates[1]
      expect(result[2]).toBe candidates[0]

      #result = filter(candidates, 'git aa')
      #expect(result[0]).toBe candidates[2]
      #expect(result[1]).toBe candidates[1]
      #expect(result[2]).toBe candidates[0]


    it "account for match structure in CamelCase vs Substring matches", ->

      candidates = [
        'Input: Select All',
        'Application: Install'
      ]

      expect(bestMatch(candidates, 'install')).toBe candidates[1]
      expect(bestMatch(candidates, 'isa')).toBe candidates[0]
      expect(bestMatch(candidates, 'isall')).toBe candidates[0]

      candidates = [
        'Git Plus: Stage Hunk',
        'Git Plus: Push'
      ]

      expect(bestMatch(candidates, 'push')).toBe candidates[1]
      expect(bestMatch(candidates, 'git push')).toBe candidates[1]
      expect(bestMatch(candidates, 'psh')).toBe candidates[0]

    # expect(bestMatch(candidates, 'git PSH')).toBe candidates[0]
    # expect(bestMatch(candidates, 'git psh')).toBe candidates[0]
    #
    # not yet supported, because we only scan acronym structure on the start of the query (acronym prefix) :(
    # it might be possible to handle uppercase playing with case sensitivity instead of structure.


    it "account for case in CamelCase vs Substring matches", ->

      candidates = [
        'CamelCaseClass.js',
        'cccManagerUI.java'
      ]

      #We test once for exact acronym
      expect(bestMatch(candidates, 'CCC')).toBe candidates[0]
      expect(bestMatch(candidates, 'ccc')).toBe candidates[1]

      #then for general purpose match.
      expect(bestMatch(candidates, 'CCCa')).toBe candidates[0]
      expect(bestMatch(candidates, 'ccca')).toBe candidates[1]


  #---------------------------------------------------
  #
  #                 Path / Fuzzy finder
  #

  describe "when the entries contains slashes", ->

    it "weighs basename matches higher", ->

      candidates = [
        rootPath('bar', 'foo')
        rootPath('foo', 'bar')
      ]
      expect(bestMatch(candidates, 'bar')).toBe candidates[1]
      expect(bestMatch(candidates, 'br')).toBe candidates[1]

    it "weighs exact basename matches higher than acronym in path", ->

      candidates = [
        path.join('c', 'o', 'r', 'e', 'foobar')
        path.join('f', 'o', 'o', 'b', 'a', 'r', 'core')
      ]

      expect(bestMatch(candidates, 'core')).toBe candidates[1]
      expect(bestMatch(candidates, 'foo')).toBe candidates[0]

    it "weighs exact match in the path higher than scattered match in the filename", ->

      candidates = [
        path.join('model', 'core', 'spec.rb')
        path.join('model', 'controller.rb')
      ]

      expect(bestMatch(candidates, 'model core')).toBe candidates[0]
      expect(bestMatch(candidates, path.join('model', 'core'))).toBe candidates[0]


    it "prefer shorter basename", ->

      # here full path is same size, but basename is smaller
      candidates = [
        path.join('test', 'core_'),
        path.join('test', '_core'),
        path.join('test_', 'core'),
      ]

      expect(bestMatch(candidates, 'core')).toBe candidates[2]


    it "ignore path separator at the end", ->

      candidates = [
        rootPath('bar', 'foo')
        rootPath('foo', 'bar', path.sep, path.sep, path.sep, path.sep, path.sep)
      ]
      expect(bestMatch(candidates, 'bar')).toBe candidates[1]
      expect(bestMatch(candidates, 'br')).toBe candidates[1]


    it "allow candidate with all slashes without error", ->
      candidates = [path.sep, path.sep + path.sep + path.sep]
      expect(filter(candidates, 'bar', maxResults: 1)).toEqual []


  describe "when the Query contains slashes (queryHasSlashes)", ->

    it "weighs end of path matches higher", ->

      candidates = [
        rootPath('test', 'filter', 'test.js')
        rootPath('filter', 'test', 'filter.js')
      ]
      expect(bestMatch(candidates, path.join('test', 'filt'))).toBe candidates[1]

      candidates = [
        rootPath('project', 'folder', 'folder', 'file')
        rootPath('folder', 'folder', 'project', 'file')
      ]
      expect(bestMatch(candidates, path.join('project', 'file'))).toBe candidates[1]
      expect(bestMatch(candidates, 'project file')).toBe candidates[0]

  # normally there's a preference for start of the string on the full-path match
  # having a separator in the query shift that preference toward the end.
  # alternative would be to always have preference for end of path - aka compactness


  describe "when the entries are of differing directory depths", ->

    it "prefer shallow path", ->

      candidate = [
        path.join('b', 'z', 'file'),
        path.join('b_z', 'file')
      ]

      expect(bestMatch(candidate, "file")).toBe candidate[1]
      expect(bestMatch(candidate, "fle")).toBe candidate[1]

      candidate = [
        path.join('foo', 'bar', 'baz', 'file'),
        path.join('foo', 'bar_baz', 'file')
      ]

      expect(bestMatch(candidate, "file")).toBe candidate[1]
      expect(bestMatch(candidate, "fle")).toBe candidate[1]

      candidate = [
        path.join('A Long User Full-Name', 'My Documents', 'file'),
        path.join('bin', 'lib', 'src', 'test', 'spec', 'file')
      ]

      expect(bestMatch(candidate, "file")).toBe candidate[0]

      # We have plenty of report on how this or that should win because file is a better basename match
      # But we have no report of searching too deep, because of that folder-depth penalty is pretty weak.


    it "allow better basename match to overcome slightly deeper directory / longer overall path", ->

      candidates = [
        path.join('f', '1_a_z')
        path.join('f', 'o', 'a_z')
      ]

      expect(bestMatch(candidates, 'az')).toBe candidates[1]

      candidates = [
        path.join('app', 'models', 'automotive', 'car.rb')
        path.join('spec', 'carts.rb')
      ]

      expect(bestMatch(candidates, 'car.rb')).toBe candidates[0]

      candidates = [
        path.join('application', 'applicationPageStateServiceSpec.js')
        path.join('view', 'components', 'actions', 'actionsServiceSpec.js')
      ]

      expect(bestMatch(candidates, 'actionsServiceSpec.js')).toBe candidates[1]
      expect(bestMatch(candidates, 'ss')).toBe candidates[1]


      candidates = [
        path.join('spec', 'models', 'user_search_spec.rb')
        path.join('spec', 'models', 'listing', 'location_detection', 'usa_spec.rb')
      ]

      expect(bestMatch(candidates, 'usa_spec')).toBe candidates[1]
      expect(bestMatch(candidates, 'usa spec')).toBe candidates[1]
      expect(bestMatch(candidates, 'usa')).toBe candidates[1]

      candidates = [
        path.join('spec', 'models', 'usa_spec.rb')
        path.join('spec', 'models', 'listing', 'location_detection', 'user_search_spec.rb')
      ]

      expect(bestMatch(candidates, 'user')).toBe candidates[1]

      candidates = [
        path.join('lib', 'exportable.rb'),
        path.join('app', 'models', 'table.rb')
      ]
      expect(bestMatch(candidates, 'table')).toBe candidates[1]


      candidates = [
        path.join('db', 'emails', 'en', 'refund_notification.html'),
        path.join('app', 'views', 'admin', 'home', 'notification.erb')
      ]

      expect(bestMatch(candidates, 'notification')).toBe candidates[1]

      candidates = [
        path.join('db', 'emails', 'en', 'refund_notification.html'),
        path.join('app', 'views', 'admin', 'home', '_notification_admin.erb')
      ]

      expect(bestMatch(candidates, '_notification')).toBe candidates[1]

      candidates = [
        path.join('javascript', 'video-package', 'video-backbone.js'),
        path.join('third_party', 'javascript', 'project-src', 'backbone', 'backbone.js')
      ]

      expect(bestMatch(candidates, 'backbone')).toBe candidates[1]

      candidates = [
        path.join('spec', 'controllers', 'apps_controller_spec.rb'),
        path.join('app', 'controllers', 'api_v2_featured', 'apps_controller.rb')
      ]

      expect(bestMatch(candidates, 'apps_controller')).toBe candidates[1]


  #
  #  Optional Characters
  #

  describe "when the query contain optional characters (generalize when the entries contains spaces)", ->

    it "allow to match path using either backward slash, forward slash, space or colon", ->

      candidate = [
        path.join('foo', 'bar'),
        path.join('model', 'user'),
      ]

      expect(bestMatch(candidate, "model user")).toBe candidate[1]
      expect(bestMatch(candidate, "model/user")).toBe candidate[1]
      expect(bestMatch(candidate, "model\\user")).toBe candidate[1]
      expect(bestMatch(candidate, "model::user")).toBe candidate[1]

    it "prefer matches where the optional character is present", ->

      candidate = [
        'ModelUser',
        'model user',
        'model/user',
        'model\\user',
        'model::user',
        'model_user',
        'model-user',
      ]

      expect(bestMatch(candidate, "mdl user")).toBe candidate[1]
      expect(bestMatch(candidate, "mdl/user")).toBe candidate[2]
      expect(bestMatch(candidate, "mdl\\user")).toBe candidate[3]
      expect(bestMatch(candidate, "mdl::user")).toBe candidate[4]
      expect(bestMatch(candidate, "mdl_user")).toBe candidate[5]
      expect(bestMatch(candidate, "mdl-user")).toBe candidate[6]


    it "weighs basename matches higher (space don't have a strict preference for slash)", ->

      candidates = [
        rootPath('bar', 'foo')
        rootPath('foo', 'bar foo')
      ]
      expect(bestMatch(candidates, 'br f')).toBe candidates[1]

    it "allow basename bonus to handle query with folder", ->

      # Without support for optional character, the basename bonus
      # would not be able to find "model" inside "user.rb" so the bonus would be 0

      candidate = [
        path.join('www', 'lib', 'models', 'user.rb'),
        path.join('migrate', 'moderator_column_users.rb')
      ]

      expect(bestMatch(candidate, "model user")).toBe candidate[0]
      expect(bestMatch(candidate, "modeluser")).toBe candidate[0]
      expect(bestMatch(candidate, path.join("model", "user"))).toBe candidate[0]


      candidate = [
        path.join('images', 'destroy_discard.png'),
        path.join('ressources', 'src', 'app.coffee')
      ]

      expect(bestMatch(candidate, "src app")).toBe candidate[1]
      expect(bestMatch(candidate, path.join("src", "app"))).toBe candidate[1]

      candidate = [
        path.join('template', 'emails-dialogs.handlebars'),
        path.join('emails', 'handlers.py')
      ]

      expect(bestMatch(candidate, "email handlers")).toBe candidate[1]
      expect(bestMatch(candidate, path.join("email", "handlers"))).toBe candidate[1]


      # But when basename is an good match, it is still preferred

      candidate = [
        path.join('models', 'user.rb'),
        path.join('migrate', 'model_users.rb')
      ]

      expect(bestMatch(candidate, "modeluser")).toBe candidate[1]


  #---------------------------------------------------
  #
  #                 Command Palette
  #


  describe "When entry are sentence / Natural language", ->

    it "Prefer consecutive characters at the start of word", ->

      candidates = [
        'Find And Replace: Select All',
        'Settings View: Uninstall Packages',
        'Settings View: View Installed Themes',
        'Application: Install Update',
        'Install'
      ]

      result = filter(candidates, 'install')
      expect(result[0]).toBe candidates[4]
      expect(result[1]).toBe candidates[3]
      expect(result[2]).toBe candidates[2]
      expect(result[3]).toBe candidates[1]
      expect(result[4]).toBe candidates[0]

      # Even when we do not have an exact match

      result = filter(candidates, 'instll')
      expect(result[0]).toBe candidates[4]
      expect(result[1]).toBe candidates[3]
      expect(result[2]).toBe candidates[2]
      expect(result[3]).toBe candidates[1]
      expect(result[4]).toBe candidates[0]

      # for this one, complete word "Install" should win against:
      #
      #  - case-sensitive end-of-word match "Uninstall",
      #  - start of word match "Installed",
      #  - double acronym match "in S t A ll" -> "Select All"
      #
      #  also "Install" by itself should win against "Install" in a sentence


    it "weighs substring higher than individual characters", ->

      candidates = [
        'Git Plus: Stage Hunk',
        'Git Plus: Reset Head',
        'Git Plus: Push',
        'Git Plus: Show'
      ]
      expect(bestMatch(candidates, 'push')).toBe candidates[2]
      expect(bestMatch(candidates, 'git push')).toBe candidates[2]
      expect(bestMatch(candidates, 'gpush')).toBe candidates[2]

      # Here "Plus Stage Hunk" accidentally match acronym on PuSH.
      # Using two words disable exactMatch bonus, we have to rely on consecutive match

