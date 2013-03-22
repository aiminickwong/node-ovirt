"use strict"


lib =  require '../lib'
Fiber = require 'fibers'
_ = require 'lodash'

fs = require 'fs'
eyes = require 'eyes'
inspect = eyes.inspector maxLength: no

libxmljs = require 'libxmljs'

secureOptions = require '../private.json'


loadResponse = (name) ->
  fs.readFileSync "#{__dirname}/responses/#{name}.xml"


dumpHydratedRequest = ->
  startStop = (vm) ->
    inspect vm.status.state

    if vm.status.state is 'down'
      result = vm.start()
    else
      result = vm.stop()

    inspect result.$properties if result?

    vm.update()
    inspect vm.status.state

  addVm = (api, name) ->
    templates = api.templates.findAll name: 'template_http'
    template = templates[0].update()

    clusters = api.clusters.findAll name: 'local_cluster'
    cluster = clusters[0].update()

    vm = api.vms.add name: name, cluster, template

    if not vm? or vm.isError
      console.log 'Error while creating VM'
      inspect vm.$properties if vm?
      return null

    vm

  fiber = Fiber ->

    connection = new lib.OVirtConnection secureOptions
    api =  do connection.connect

    vms = api.vms.findAll name: 'db-vm2'
    startStop vms[0]

    newVm = addVm api, 'custom_vm_1'
    inspect newVm?.$properties

  do fiber.run


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