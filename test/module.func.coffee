"use strict"


lib =  require '../lib'
_ = require 'lodash'
Sync = require 'sync'

fs = require 'fs'
eyes = require 'eyes'
inspect = eyes.inspector maxLength: no

libxmljs = require 'libxmljs'

secureOptions = require '../private.json'


loadResponse = (name) ->
  fs.readFileSync "#{__dirname}/responses/#{name}.xml"


dumpHydratedRequest = ->
  startStop = (vm) ->
    console.log '------ Start/stop VM -------'

    inspect vm.status.state

    try
      if vm.status.state is 'down'
        result = vm.start()
      else
        result = vm.stop()

      inspect result.$properties
      vm.update()
    catch error
      console.log 'Error while strarting/stopping VM'
      inspect error.response.$properties

    inspect vm.status.state

  addVm = (api, name) ->
    templates = api.templates.findAll name: 'prealloc_template'
    template = templates[0].update()

    clusters = api.clusters.findAll name: 'local_cluster'
    cluster = clusters[0].update()

    try
      vm = api.vms.add name: name, cluster, template
    catch error
      console.log 'Error while creating VM'
      inspect error.response.$properties
      return null

    vm

  deleteVm = (vm) ->
    console.log '---------- Delete ----------'

    Sync.sleep 5000

    try
      removed = vm.remove()
      inspect removed: removed
    catch error
      inspect error


  connection = new lib.OVirtConnection secureOptions
  connection.connect (api) ->
    console.log '-------- VM search ---------'

    unless api.vms.getOneById 'wrong id'
      console.log "Can't find resource with wrong ID."

    vm = api.vms.findOne name: 'db-vm2'
    vm = api.vms.getOneById vm.id

    startStop vm

    newVm = addVm api, 'custom-vm-1'
    if newVm?
      console.log '---- VM creation report ----'
      inspect newVm.$attributes
      inspect newVm.$properties
      console.log '----------- Nics -----------'
      inspect nic.$properties for nic in newVm.nics.getAll()

    deleteVm newVm


playWithXmlDom = (file = 'api') ->
  xml = loadResponse file
  libxmlDoc = libxmljs.parseXml xml

  collections = libxmlDoc.find '//*[not(name()="special_objects")]/link[@href and @rel and not(contains(@rel, "/search"))]'

  for collection in collections
    rel = collection.attr('rel').value()

    searchOption = collection.get "../link[@href and @rel='#{rel}/search']"
    if searchOption?
      collection.attr search: searchOption.remove().attr('href').value()

    specialObjects = collection.find "../special_objects/link[@href and @rel and starts-with(@rel, '#{rel}/')]"
    if specialObjects?.length > 0 then for specialObject in specialObjects
      objectRel = specialObject.attr('rel').value().replace "#{rel}/", ''
      specialObject.attr('rel').value objectRel

      collection.addChild specialObject.remove()

    inspect rel
    console.log collection.toString()

    inspect entry.attr('rel').value() for entry in libxmlDoc.find '//special_objects/link[@href and @rel]'
    inspect entry.name() for entry in libxmlDoc.find '/*//*[@href and @id]'

#    inspect entry for entry in libxmlDoc.find '//link[@href and @rel and not(contains(@rel, "/search"))]'


do dumpHydratedRequest
#do playWithXmlDom