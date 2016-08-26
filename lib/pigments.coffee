{CompositeDisposable, Disposable} = require 'atom'
uris = require './uris'
ColorProject = require './color-project'
[PigmentsProvider, PigmentsAPI, url] = []

module.exports =
  activate: (state) ->
    @patchAtom()

    @project = if state.project?
      atom.deserializers.deserialize(state.project)
    else
      new ColorProject()

    atom.commands.add 'atom-workspace',
      'pigments:find-colors': => @findColors()
      'pigments:show-palette': => @showPalette()
      'pigments:project-settings': => @showSettings()
      'pigments:reload': => @reloadProjectVariables()
      'pigments:report': => @createPigmentsReport()

    convertMethod = (action) => (event) =>
      if @lastEvent?
        action @colorMarkerForMouseEvent(@lastEvent)
      else
        editor = atom.workspace.getActiveTextEditor()
        colorBuffer = @project.colorBufferForEditor(editor)

        editor.getCursors().forEach (cursor) =>
          marker = colorBuffer.getColorMarkerAtBufferPosition(cursor.getBufferPosition())
          action(marker)

      @lastEvent = null

    copyMethod = (action) => (event) =>
      if @lastEvent?
        action @colorMarkerForMouseEvent(@lastEvent)
      else
        editor = atom.workspace.getActiveTextEditor()
        colorBuffer = @project.colorBufferForEditor(editor)
        cursor = editor.getLastCursor()
        marker = colorBuffer.getColorMarkerAtBufferPosition(cursor.getBufferPosition())
        action(marker)

      @lastEvent = null

    atom.commands.add 'atom-text-editor',
      'pigments:convert-to-hex': convertMethod (marker) ->
        marker.convertContentToHex() if marker?

      'pigments:convert-to-rgb': convertMethod (marker) ->
        marker.convertContentToRGB() if marker?

      'pigments:convert-to-rgba': convertMethod (marker) ->
        marker.convertContentToRGBA() if marker?

      'pigments:convert-to-hsl': convertMethod (marker) ->
        marker.convertContentToHSL() if marker?

      'pigments:convert-to-hsla': convertMethod (marker) ->
        marker.convertContentToHSLA() if marker?

      'pigments:copy-as-hex': copyMethod (marker) ->
        marker.copyContentAsHex() if marker?

      'pigments:copy-as-rgb': copyMethod (marker) ->
        marker.copyContentAsRGB() if marker?

      'pigments:copy-as-rgba': copyMethod (marker) ->
        marker.copyContentAsRGBA() if marker?

      'pigments:copy-as-hsl': copyMethod (marker) ->
        marker.copyContentAsHSL() if marker?

      'pigments:copy-as-hsla': copyMethod (marker) ->
        marker.copyContentAsHSLA() if marker?

    atom.workspace.addOpener (uriToOpen) =>
      url ||= require 'url'

      {protocol, host} = url.parse uriToOpen
      return unless protocol is 'pigments:'

      switch host
        when 'search' then @project.findAllColors()
        when 'palette' then @project.getPalette()
        when 'settings' then atom.views.getView(@project)

    atom.contextMenu.add
      'atom-text-editor': [{
        label: 'Pigments'
        submenu: [
          {label: 'Convert to hexadecimal', command: 'pigments:convert-to-hex'}
          {label: 'Convert to RGB', command: 'pigments:convert-to-rgb'}
          {label: 'Convert to RGBA', command: 'pigments:convert-to-rgba'}
          {label: 'Convert to HSL', command: 'pigments:convert-to-hsl'}
          {label: 'Convert to HSLA', command: 'pigments:convert-to-hsla'}
          {type: 'separator'}
          {label: 'Copy as hexadecimal', command: 'pigments:copy-as-hex'}
          {label: 'Copy as RGB', command: 'pigments:copy-as-rgb'}
          {label: 'Copy as RGBA', command: 'pigments:copy-as-rgba'}
          {label: 'Copy as HSL', command: 'pigments:copy-as-hsl'}
          {label: 'Copy as HSLA', command: 'pigments:copy-as-hsla'}
        ]
        shouldDisplay: (event) => @shouldDisplayContextMenu(event)
      }]

  deactivate: ->
    @getProject()?.destroy?()

  provideAutocomplete: ->
    PigmentsProvider ?= require './pigments-provider'
    new PigmentsProvider(this)

  provideAPI: ->
    PigmentsAPI ?= require './pigments-api'
    new PigmentsAPI(@getProject())

  consumeColorPicker: (api) ->
    @getProject().setColorPickerAPI(api)

    new Disposable =>
      @getProject().setColorPickerAPI(null)

  consumeColorExpressions: (options={}) ->
    registry = @getProject().getColorExpressionsRegistry()

    if options.expressions?
      names = options.expressions.map (e) -> e.name
      registry.createExpressions(options.expressions)

      new Disposable -> registry.removeExpression(name) for name in names
    else
      {name, regexpString, handle, scopes, priority} = options
      registry.createExpression(name, regexpString, priority, scopes, handle)

      new Disposable -> registry.removeExpression(name)

  consumeVariableExpressions: (options={}) ->
    registry = @getProject().getVariableExpressionsRegistry()

    if options.expressions?
      names = options.expressions.map (e) -> e.name
      registry.createExpressions(options.expressions)

      new Disposable -> registry.removeExpression(name) for name in names
    else
      {name, regexpString, handle, scopes, priority} = options
      registry.createExpression(name, regexpString, priority, scopes, handle)

      new Disposable -> registry.removeExpression(name)

  shouldDisplayContextMenu: (event) ->
    @lastEvent = event
    setTimeout (=> @lastEvent = null), 10
    @colorMarkerForMouseEvent(event)?

  colorMarkerForMouseEvent: (event) ->
    editor = atom.workspace.getActiveTextEditor()
    colorBuffer = @project.colorBufferForEditor(editor)
    colorBufferElement = atom.views.getView(colorBuffer)
    colorBufferElement?.colorMarkerForMouseEvent(event)

  serialize: -> {project: @project.serialize()}

  getProject: -> @project

  findColors: ->
    pane = atom.workspace.paneForURI(uris.SEARCH)
    pane ||= atom.workspace.getActivePane()

    atom.workspace.openURIInPane(uris.SEARCH, pane, {})

  showPalette: ->
    @project.initialize().then ->
      pane = atom.workspace.paneForURI(uris.PALETTE)
      pane ||= atom.workspace.getActivePane()

      atom.workspace.openURIInPane(uris.PALETTE, pane, {})
    .catch (reason) ->
      console.error reason

  showSettings: ->
    @project.initialize().then ->
      pane = atom.workspace.paneForURI(uris.SETTINGS)
      pane ||= atom.workspace.getActivePane()

      atom.workspace.openURIInPane(uris.SETTINGS, pane, {})
    .catch (reason) ->
      console.error reason

  reloadProjectVariables: ->
    @project.initialize().then =>
      @project.loadPathsAndVariables()
    .catch (reason) ->
      console.error reason

  createPigmentsReport: ->
    atom.workspace.open('pigments-report.json').then (editor) =>
      editor.setText(@createReport())

  createReport: ->
    o =
      atom: atom.getVersion()
      pigments: atom.packages.getLoadedPackage('pigments').metadata.version
      platform: require('os').platform()
      config: atom.config.get('pigments')
      project:
        config:
          sourceNames: @project.sourceNames
          searchNames: @project.searchNames
          ignoredNames: @project.ignoredNames
          ignoredScopes: @project.ignoredScopes
          includeThemes: @project.includeThemes
          ignoreGlobalSourceNames: @project.ignoreGlobalSourceNames
          ignoreGlobalSearchNames: @project.ignoreGlobalSearchNames
          ignoreGlobalIgnoredNames: @project.ignoreGlobalIgnoredNames
          ignoreGlobalIgnoredScopes: @project.ignoreGlobalIgnoredScopes
        paths: @project.getPaths()
        variables:
          colors: @project.getColorVariables().length
          total: @project.getVariables().length

    JSON.stringify(o, null, 2)
    .replace(///#{atom.project.getPaths().join('|')}///g, '<root>')

  patchAtom: ->
    requireCore = (name) ->
      require Object.keys(require.cache).filter((s) -> s.indexOf(name) > -1)[0]

    HighlightComponent = requireCore('highlights-component')
    TextEditorPresenter = requireCore('text-editor-presenter')

    unless TextEditorPresenter.getTextInScreenRange?
      TextEditorPresenter::getTextInScreenRange = (screenRange) ->
        if @displayLayer?
          @model.getTextInRange(@displayLayer.translateScreenRange(screenRange))
        else
          @model.getTextInRange(@model.bufferRangeForScreenRange(screenRange))

      _buildHighlightRegions = TextEditorPresenter::buildHighlightRegions
      TextEditorPresenter::buildHighlightRegions = (screenRange) ->
        regions = _buildHighlightRegions.call(this, screenRange)

        if regions.length is 1
          regions[0].text = @getTextInScreenRange(screenRange)
        else
          regions[0].text = @getTextInScreenRange([
            screenRange.start
            [screenRange.start.row, Infinity]
          ])
          regions[regions.length - 1].text = @getTextInScreenRange([
            [screenRange.end.row, 0]
            screenRange.end
          ])

          if regions.length > 2
            regions[1].text = @getTextInScreenRange([
              [screenRange.start.row + 1, 0]
              [screenRange.end.row - 1, Infinity]
            ])

        regions

      _updateHighlightRegions = HighlightComponent::updateHighlightRegions
      HighlightComponent::updateHighlightRegions = (id, newHighlightState) ->
        _updateHighlightRegions.call(this, id; newHighlightState)

        if newHighlightState.class?.match /^pigments-native-background\s/
          for newRegionState, i in newHighlightState.regions
            regionNode = @regionNodesByHighlightId[id][i]

            regionNode.textContent = newRegionState.text if newRegionState.text?

  loadDeserializersAndRegisterViews: ->
    ColorBuffer = require './color-buffer'
    ColorSearch = require './color-search'
    Palette = require './palette'
    ColorBufferElement = require './color-buffer-element'
    ColorMarkerElement = require './color-marker-element'
    ColorResultsElement = require './color-results-element'
    ColorProjectElement = require './color-project-element'
    PaletteElement = require './palette-element'
    VariablesCollection = require './variables-collection'

    ColorBufferElement.registerViewProvider(ColorBuffer)
    ColorResultsElement.registerViewProvider(ColorSearch)
    ColorProjectElement.registerViewProvider(ColorProject)
    PaletteElement.registerViewProvider(Palette)

    atom.deserializers.add(Palette)
    atom.deserializers.add(ColorSearch)
    atom.deserializers.add(ColorProject)
    atom.deserializers.add(ColorProjectElement)
    atom.deserializers.add(VariablesCollection)

module.exports.loadDeserializersAndRegisterViews()
