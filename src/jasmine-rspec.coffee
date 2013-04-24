subject = null
shared_examples = {}
context = describe
before = beforeEach
after = afterEach

xthe = xit

subject = (name, block) ->
  [name, block] = [block, name] if typeof name is 'function'
  beforeEach ->
    @subject = block.call this
    @[name] = @subject if name?

let_ = given = (name, block) =>

  beforeEach ->
    self = this
    Object.defineProperty this, name,
                          configurable: true,
                          enumerable: true,
                          get: -> self["__#{name}"] ?= block.call self
  afterEach ->
    delete @[name]

expect_its = expectIts = (thing, f) ->
  it "its #{thing} should ...", ->
    f.call expect(eval("subject.#{thing}"))

expect_it = expectIt = (f) ->
  it "should ...", ->
    f.call expect(subject)

shared_examples_for = sharedExamplesFor = (name, f) ->
  shared_examples[name] = f

it_should_behave_like = itShouldBehaveLike = (name, g) ->
  f = shared_examples[name]
  f?()
  g?()

last_when = null

when_ = (desc, f) ->
  last_when = [desc, f]

then_ = (g) ->
  [desc, f] = last_when
  context "when #{desc}", ->
    before f if f
    g()

jit = it
dummy_subject =
  should: (matcher) -> matcher
  should_not: (matcher) -> matcher.reverse

it_ = (f) ->
  jit "", ->
    matcher = f.call dummy_subject
    m = matcher.complete subject
    this.description = "it should #{m.description()}"
    expect(m).toBeRspec()

its = (thing, f) ->
  jit "", ->
    matcher = f.call dummy_subject
    m = matcher.complete eval("subject.#{thing}")
    this.description = "its #{thing} should #{m.description()}"
    expect(m).toBeRspec()

the = (thing, f) ->
  jit "", ->
    matcher = f.call dummy_subject
    m = matcher.complete eval("window.#{thing}")
    this.description = "the #{thing} should #{m.description()}"
    expect(m).toBeRspec()

_should = (actual, matcher) ->
  m = matcher.complete(actual)
  expect(m).toBeRspec()

_ = (x) ->
  should: (matcher) ->
    _should(x, matcher)
  should_not: (matcher) ->
    _should(x, matcher.reverse)

it = (desc, f) ->
  if f
    jit desc, f
  else
    it_ desc

# matcher stuff

matcher = (f) ->
  return ->
    desc = rev_desc = null
    matches = rev_matches = null
    msg = rev_msg = null
    helpers = null
    args = arguments
    rev =
      description: (g) -> rev_desc = g
      matches: (g) -> rev_matches = g
      message: (g) -> rev_msg = g
    body =
      description: (g) -> desc = g
      matches: (g) -> matches = g
      message: (g) -> msg = g
      reverse: (g) -> g.apply(rev, args)
      helpers: (g) -> helpers = g.apply(body, args)
    f.apply(body, args)
    rev_desc ||= -> "not #{desc()}"
    _fn = (obj, name, f) -> obj[name] = -> f.apply(obj, arguments)
    return(
      description: desc
      reverse:
        description: rev_desc
        complete: (actual) ->
          ret =
            actual: actual
            description: rev_desc
          rev_matches ||= -> !matches.call(ret)
          ret.matches = -> rev_matches.call(ret)
          if rev_msg
            ret.message = -> rev_msg.call(ret)
          _fn(ret, name, g) for own name, g of helpers
          ret
      complete: (actual) ->
        ret =
          actual: actual
          description: desc
        ret.matches = -> matches.call(ret)
        if msg
          ret.message = -> msg.call(ret)
        _fn(ret, name, g) for own name, g of helpers
        ret
    )

respond_to = respondTo = matcher (name) ->
  @description -> "respond to .#{name}()"
  @matches -> typeof(@actual[name]) == 'function'
  @message -> "Expected it to #{@description()}"
  @reverse -> @message -> "Expected it not to #{@description()}"

have = matcher (number, collection) ->
  @description -> "contain #{number} #{collection}"
  @matches ->
    if @actual[collection]
      @actual[collection].length == number
    else
      @actual.length == number

be_null = beNull = matcher ->
  @description -> "be null"
  @matches -> @actual == null

be_empty = beEmpty = matcher ->
  @description -> "be empty"
  @matches ->
    for own x,y of @actual
      return false
    true

match = matcher (pattern) ->
  @description -> "match #{pattern}"
  @matches -> pattern.test(@actual)

equal = matcher (expected) ->
  @description -> "equal #{JSON.stringify(expected)}"
  @matches -> jasmine.getEnv().equals_(@actual, expected)

be_true = beTrue = matcher ->
  @description -> "be true"
  @matches -> @actual == true

be_false = beFalse = matcher ->
  @description -> "be false"
  @matches -> @actual == false

include = matcher (item) ->
  @description -> "include #{item}"
  @matches -> @actual.indexOf(item) != -1

be_greater_than = beGreaterThan = matcher (value) ->
  @description -> "be greater than #{value}"
  @matches -> @actual > value
  @reverse -> @description -> "be less than or equal to #{value}"

be_less_than = beLessThan = matcher (value) ->
  @description -> "be less than #{value}"
  @matches -> @actual < value
  @reverse -> @description -> "be greater than or equal to #{value}"

be_called = beCalled = matcher ->
  @description -> "have been called"
  @matches -> @actual.wasCalled

propagate = matcher ->
  @reverse ->
    @description -> "not propagate"
    @matches -> @actual.stopPropagation.wasCalled

be_within = beWithin = (tol) ->
  of: matcher (expected) ->
    @helpers ->
      diff: ->
        diff = @actual - expected
        diff = -diff if diff < 0
        diff

    @description -> "be within #{tol} of #{expected}"
    @matches -> @diff() < tol
    @message -> "Expected #{@actual} to be within #{tol} of #{expected}, but was off by #{@diff()}"

    @reverse ->
      @description -> "be outside #{tol} of #{expected}"
      @message -> "Expected #{@actual} to be outside #{tol} of #{expected}, but was within #{@diff()}"

have_query_string = haveQueryString = matcher (query) ->
  @helpers ->
    query_part: -> @actual.split('?')[1]
  @description -> "have query string '#{query}'"
  @matches -> unescape(@query_part()) == query

be = matcher (name) ->
  @description -> "be #{name}"
  @matches -> eval "this.actual.is_#{name}()"

have_table_data = haveTableData = matcher (data) ->
  @description -> "have tabular data"
  @matches ->
    real = for own tr in @actual.find('tr')
      $(td).text() for own td in $(tr).find('td,th')
    jasmine.getEnv().equals_(real, data)

have_css_class = haveCSSClass = matcher (name) ->
  @description -> "have css class '#{name}'"
  @matches -> @actual.hasClass(name)
  @message -> "Expected node to have css class '#{name}'"

select = matcher (count, selector) ->
  @helpers ->
    actual_count: -> @actual.find(selector).size()
  @description -> "select #{count} elements with '#{selector}'"
  @matches -> @actual_count() == count
  @message -> "Expected node to select #{count} elements with '#{selector}', actually selected #{@actual_count()}"

contain_text = containText = matcher (text) ->
  @description -> "contain text #{text}"
  @message -> "Expected node to contain text '#{text}', was '#{@actual.text()}'"
  @matches -> @actual.text().strip() == text

match_object = matchObject = matcher (object) ->
  @description -> "match #{JSON.stringify(object)}"
  @matches ->
    for own key, value of object
      return false unless jasmine.getEnv().equals_(@actual[key], value)
    true
  @message -> "Expected the object to match #{JSON.stringify(object)}"

beforeEach ->
  @addMatchers
    toBeRspec: (reverse) ->
      m = @actual
      if m.matches()
        true
      else
        if m.message
          @message = m.message
        else
          @message = ->
            not_str = (" NOT " if reverse) || " "
            try
              "Expected #{JSON.stringify(m.actual)}#{not_str}to #{m.description()}"
            catch e
              "Expected it#{not_str}to #{m.description()}"
        false
