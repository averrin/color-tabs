sep = require("path").sep
log = require("atom-simple-logger")(pkg:"color-tabs",nsp:"core")
CSON = require 'season'
colorFile = atom.getConfigDirPath()+"color-tabs.cson"
colors = {}
colorChangeCb = null
cssElements = {}
getCssElement = (path, color) ->
  cssElement = cssElements[path]
  unless cssElement?
    cssElement = document.createElement 'style'
    cssElement.setAttribute 'type', 'text/css'
    cssElements[path] = cssElement
  while cssElement.firstChild?
    cssElement.removeChild cssElement.firstChild
  path = path.replace(/\\/g,"\\\\")
  text_color = if (parseInt(color.replace('#', ''), 16) > 0xffffff/2) then '#111' else '#eee'
  cssElement.appendChild document.createTextNode """
  ul.tab-bar>li.tab[data-path='#{path}'],
  ul.tab-bar>li.tab[data-path='#{path}']:before,
  ul.tab-bar>li.tab[data-path='#{path}']:after,
  atom-workspace.theme-atom-light-ui ul.tab-bar>li.tab[data-path='#{path}'].active,
  atom-workspace.theme-atom-light-ui ul.tab-bar>li.tab[data-path='#{path}'].active:before,
  atom-workspace.theme-atom-light-ui ul.tab-bar>li.tab[data-path='#{path}'].active:after{
    background-color: #{color};
  }
  atom-workspace.theme-atom-dark-ui ul.tab-bar>li.tab[data-path='#{path}'],
  atom-workspace.theme-atom-dark-ui ul.tab-bar>li.tab[data-path='#{path}']:before,
  atom-workspace.theme-atom-dark-ui ul.tab-bar>li.tab[data-path='#{path}']:after{
    background-color: #{color};
  }
  atom-workspace.theme-atom-dark-ui ul.tab-bar>li.tab[data-path='#{path}'].active,
  atom-workspace.theme-atom-dark-ui ul.tab-bar>li.tab[data-path='#{path}'].active:before,
  atom-workspace.theme-atom-dark-ui ul.tab-bar>li.tab[data-path='#{path}'].active:after{
    background-color: #{color};
  }
  atom-workspace.theme-atom-light-ui ul.tab-bar>li.tab[data-path='#{path}'],
  atom-workspace.theme-atom-light-ui ul.tab-bar>li.tab[data-path='#{path}']:before,
  atom-workspace.theme-atom-light-ui ul.tab-bar>li.tab[data-path='#{path}']:after{
    background-color: #{color};
  }
  ul.tab-bar>li.tab[data-path='#{path}'] div.foldername-tabs>span.file,
  ul.tab-bar>li.tab[data-path='#{path}'] div.foldername-tabs>span.folder  {
    color: #{text_color}
  }
  """
  return cssElement
getRandomColor= ->
  letters = '0123456789ABCDEF'.split('')
  color = '#'
  for i in [0..5]
    color += letters[Math.floor(Math.random() * 16)]
  return color

processPath= (path,color,revert=false,save=false) ->
  cssElement = getCssElement path, color
  unless revert
    if save
      colors[path] = color
      CSON.writeFile colorFile, colors, ->
    tabDivs = atom.views.getView(atom.workspace).querySelectorAll "ul.tab-bar>
      li.tab[data-type='TextEditor']>
      div.title[data-path='#{path.replace(/\\/g,"\\\\")}']"
    for tabDiv in tabDivs
      tabDiv.parentElement.setAttribute "data-path", path
    unless cssElement.parentElement?
      head = document.getElementsByTagName('head')[0]
      head.appendChild cssElement
  else
    if save
      delete colors[path]
      CSON.writeFile colorFile, colors, ->
    if cssElement.parentElement?
      cssElement.parentElement.removeChild(cssElement)
  if colorChangeCb?
    for cb in colorChangeCb
      unless revert
        cb path, color
      else
        cb path, false

processAllTabs= (revert=false)->
  log "processing all tabs, reverting:#{revert}"
  paths = []
  paneItems = atom.workspace.getPaneItems()
  for paneItem in paneItems
    if paneItem.getPath?
      path = paneItem.getPath()
      if path? and paths.indexOf(path) == -1 and colors[path]?
        paths.push path
  log "found #{paths.length} different paths with color of
    total #{paneItems.length} paneItems",2
  for path in paths
    processPath path, colors[path], revert
  return !revert


{CompositeDisposable} = require 'atom'
paths = {}

module.exports =
class ColorTabs
  disposables: null

  constructor:  ->
    CSON.readFile colorFile, (err, content) =>
      unless err
        colors = content
        @processed = processAllTabs()
    unless @disposables?
      @disposables = new CompositeDisposable
      @disposables.add atom.workspace.onDidAddTextEditor ->
        setTimeout processAllTabs, 10
      @disposables.add atom.workspace.onDidDestroyPaneItem ->
        setTimeout processAllTabs, 10
      @disposables.add atom.commands.add 'atom-workspace',
        'color-tabs:toggle': @toggle
        'color-tabs:color-current-tab': =>
          te = atom.workspace.getActiveTextEditor()
          if te?.getPath?
            @color te.getPath(), getRandomColor()
        'color-tabs:uncolor-current-tab': =>
          te = atom.workspace.getActiveTextEditor()
          if te?.getPath?
            @color te.getPath(), false
    log "loaded"
  color: (path, color) ->
    processPath path, color, !color, true
  setColorChangeCb: (instance)->
    colorChangeCb = instance
  getColors: ->
    if @processed
      return colors
    else
      return {}
  toggle: =>
    @processed = processAllTabs(@processed)
  destroy: =>
    @processed = processAllTabs(true)
    @disposables?.dispose()
    @disposables = null
