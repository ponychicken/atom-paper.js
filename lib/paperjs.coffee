url = require 'url'

PaperjsView = require './paperjs-view'
{CompositeDisposable} = require 'atom'

paperprotocol = 'paperjs:'

module.exports = Paperjs =
  paperjsView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'Paper.js:toggle': => @toggle()

    atom.workspace.registerOpener (uriToOpen) ->
      {protocol, host, pathname} = url.parse(uriToOpen)

      return unless protocol is paperprotocol

      pathname = decodeURI(pathname) if pathname

      if host is 'editor'
        new PaperjsView(editorId: pathname.substring(1))
      else
        new PaperjsView(filePath: pathname)

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @paperjsView.destroy()

  serialize: ->
    # This currently doesn't work, see https://github.com/atom/atom/issues/3695
    paperjsViewState: @paperjsView.serialize()

  toggle: ->
    editor = atom.workspace.getActiveEditor()
    return unless editor?

    uri = paperprotocol + "//editor/#{editor.id}"

    previewPane = atom.workspace.paneForUri(uri)
    if previewPane
      previewPane.destroyItem(previewPane.itemForUri(uri))
      return

    previousActivePane = atom.workspace.getActivePane()
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (paperjsView) ->
      if paperjsView instanceof PaperjsView
        paperjsView.renderHTML()
        previousActivePane.activate()
