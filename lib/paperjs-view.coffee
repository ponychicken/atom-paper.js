path = require 'path'
fs = require 'fs'
{$, $$$, ScrollView} = require 'atom'

{allowUnsafeEval, allowUnsafeNewFunction} = require 'loophole'

paperEngine = allowUnsafeNewFunction -> require('../external/paperjs-full.js')

module.exports =
class PaperjsView extends ScrollView
  atom.deserializers.add(this)

  @deserialize: (state) ->
    new PaperjsView(state)

  @content: ->
    @div class: 'paperjs native-key-bindings', tabindex: -1

  constructor: ({@editorId, filePath}) ->
    super

    if @editorId?
      @resolveEditor(@editorId)
    else
      if atom.workspace?
        @subscribeToFilePath(filePath)
      else
        @subscribe atom.packages.once 'activated', =>
          @subscribeToFilePath(filePath)

    window.addEventListener 'resize', (e) =>
      @handleResize e
      
    @console = {
      log: =>
        @print('log', arguments);
  
      error: =>
        @print('error', arguments);
  
      warn: =>
        @print('warn', arguments);
  
      clear: =>
        @consoleContainer.empty();
    }

  serialize: ->
    deserializer: 'PaperjsView'
    filePath: @getPath()
    editorId: @editorId

  destroy: ->
    @unsubscribe()

  subscribeToFilePath: (filePath) ->
    @trigger 'title-changed'
    @handleEvents()
    @renderHTML()

  resolveEditor: (editorId) ->
    resolve = =>
      @editor = @editorForId(editorId)

      if @editor?
        @trigger 'title-changed' if @editor?
        @handleEvents()
      else
        # The editor this preview was created for has been closed so close
        # this preview since a preview cannot be rendered without an editor
        @parents('.pane').view()?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      @subscribe atom.packages.once 'activated', =>
        resolve()
        @renderHTML()

  editorForId: (editorId) ->
    for editor in atom.workspace.getEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  handleEvents: ->

    changeHandler = =>
      @renderHTML()
      pane = atom.workspace.paneForUri(@getUri())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)

    if @editor?
      @subscribe(@editor.getBuffer(), 'contents-modified', changeHandler)
      @subscribe @editor, 'path-changed', => @trigger 'title-changed'


  handleResize: (event) ->
    size = {
      width: @width(),
      height: @height()
    }
    @curPaper.project._view.setViewSize(size)

  renderHTML: ->
    @showLoading()
    @setupStructure()
    if @editor?
      @renderHTMLCode(@editor.getText())

  setupStructure: ->
    @empty()
    @mainContainer = $('<div id="main">')
    @consoleContainer = $('<div id="console">')
    
    @append @mainContainer
    @append @consoleContainer

  toString: (thing) ->
    string = ""
    if (thing instanceof Array)
      constr = thing.constructor.name
      props = []
      
      for value, index in thing
        string = index
        string += ": "
        string += @toString(value)
        props.push(string)
      
      string = constr + " [" + props.join(", ") + "]"
            
    else if (typeof thing == 'object')
      constr = thing.constructor.name
      props = []
      
      for key, value of thing
        string = key
        string += ": "
        string += @toString(value)
        props.push(string)
        
      string = constr + " {" + props.join(", ") + "}"
    
    else if (typeof thing == 'undefined')
      string = typeof thing
    else if (thing.toString)
      string = thing.toString()
    else
      string = typeof thing
      
    return string
    
  # Prints an arbitrary string to the in built console.
  print: (type, args) ->
    line = $("<div class='line'>")
    stringedArgs = []
    for arg in args
      stringedArgs.push(@toString(arg))

    line.append(stringedArgs.join(', '))
    @consoleContainer.append(line)
    container = @consoleContainer
    container.scrollTop = container.scrollHeight

  renderHTMLCode: (text) ->
    success = false
    @canvas = document.createElement('canvas')
    @canvas.width = @width()
    @canvas.height = @height()
    @curPaper = new paperEngine.initialize()
    @curPaper.setup(@canvas)
    @curPaper.console = @console

    try
      allowUnsafeNewFunction => @curPaper.execute(text, '', {});
      success = true
    catch e
      error = document.createElement('div')
      error.innerHTML = 'Error interpreting the Paper.js script: ' + e.message
      error.id = 'error'

    @mainContainer.html($(error || @canvas))
    @trigger('paperjs:html-changed')

  getTitle: ->
    if @editor?
      "#{@editor.getTitle()} Preview"
    else
      "Paper.js Preview"

  getUri: ->
    "paperjs://editor/#{@editorId}"

  getPath: ->
    if @editor?
      @editor.getPath()

  showError: (result) ->
    failureMessage = result?.message

    @html $$$ ->
      @h2 'Paper.js Previewing HTML Failed'
      @h3 failureMessage if failureMessage?

  showLoading: ->
    @html $$$ ->
      @div class: 'atom-html-spinner', 'Loading Paper.js Preview\u2026'
