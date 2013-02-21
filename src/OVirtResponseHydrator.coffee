"use strict"

# Tools.
_ = require 'lodash'

# Dependencies.
OVirtApi = require __dirname + '/OVirtApi'
OVirtApiNode = require __dirname + '/OVirtApiNode'
OVirtCollection = require __dirname + '/OVirtCollection'
OVirtResource = require __dirname + '/OVirtResource'

#
# This class hydrates oVirt API responses mapped to hashes by
# {OVirtResponseParser}.
#
# + It tries to find top-level collections links and exports them to target.
# - Tries to detect construct links to resources.
# - Investigates for embedded collections links and process them.
# - Exports all other "plain" properties as hashes.
#
#
# Currently oVirt API responses has a following structure:
# ---------------------------------------------------------
#
# ### API
#
# * Collections (as a links)
# * Special objects (collection members with special rel's)
# * Links to resources (not in current version)
# * Properties
#
# ### Collections
#
# * Array of resources
#
# ### Resources
#
# * ID and hreg attributes that identifies resource
# * Subcollections (same as collections) as a links
# * Special objects as mentioned before.
# * Links to resources
# * Actions (special links).
# * Properties.
#
#
# Hydration tasks
# ----------------
# Assuming that collections and resource links and resources are top-level
# objects.
#
# ### Hydrate top level element attributes
#
# - Save attributes in corresponding property if existed.
#
# ### Hydrate collections
#
# - Detect collection links.
# - Detect search options.
# - Instantiate collection objects.
# - Detect special objects inks and put them into collection.
# - Save results in collection property.
#
# ### Hydrate resource links
#
# - Detect links to resources
# - Instantiate resource objects in link mode.
# - Save results in resource links property.
#
# ### Hydrate resources
#
# - Detect resources.
# - Delegate resource hydration to other hydrator instance.
# - Save results in resources property.
#
# ### Hydrate actions
#
# - Detect actions
# - Instantiates actions objects
#
# ### Hydrate properties
#
# - Detect properties
# - Save them in corresponding property.
#
#
# Export tasks
# -------------
#
# - Export attributes.
# - Export collections.
# - Export resources.
# - Export resource links.
# - Export properties.
#
#
# Utility tasks
# --------------
#
# + Target setter should be able to create targets from strings and
# constructor function.
# + Get element attributes for custom hash.
# + Detect whether element has attributes.
# + Detect whether element has children.
# + Retrieve element's children (but not attributes).
# - Merge attributes with children (for plain properties).
# - Retrieve merged version of element.
# - Detect whether element is a link (it has href and id or rel property).
# - Detect resource hrefs.
# - Detect hrefs that leads to collections.
#
class OVirtResponseHydrator
  # Static properties
  @SPECIAL_PROPERTIES = ['link', 'action', 'special_objects']
  @LINK_PROPERTY = 'link'
  @ACTION_PROPERTY = 'action'
  @ATTRIBUTE_KEY = '$'
  @SPECIAL_OBJECTS = 'special_objects'

  # Defaults
  _target: null
  _hash: {}

  #
  # Utility methods that help to create getters and setters.
  #
  get = (props) => @:: __defineGetter__ name, getter for name, getter of props
  set = (props) => @::__defineSetter__ name, setter for name, setter of props

  #
  # @property [OVirtApiNode] target API node
  #
  get target: -> @_target
  set target: (target) ->
    @setTarget target

  #
  # @property [Object] oVirt hash
  #
  get hash: -> @_hash
  set hash: (hash) ->
    @_hash = hash

  #
  # Sets current target.
  #
  # If target is a function the it considered as a constructor of the response
  # subject.
  #
  # If target is a string then it tries convert it to API node constructor
  # using {OVirtApiNode API node's} types hash (API_NODE_TYPES).
  #
  # @param target [String, Function, OVirtApiNode] response subject
  #
  # @throw [TypeError]
  #
  setTarget: (target) ->
    if typeof target is 'string'
      target = OVirtApiNode.API_NODE_TYPES[target]

    if typeof target is 'function'
      target = new target connection: @connection

    if not (target instanceof OVirtApiNode)
      throw new
      TypeError "Hydrator's target should be an OVirtApiNode instance"

    @_target = target

  #
  # Accepts hydration parameters.
  #
  # @param  target [OVirtApiNode] response subject
  # @param  hash [Object] oVirt response as a hash
  #
  # @throw ["Hydrator's target should be an OVirtApiNode instance"]
  #
  constructor: (@target, @hash) ->

  #
  # Hydrates hash to target.
  #
  # + Searches hash for collections and exports them to target.
  # - Searches hash for properties and exports them.
  #
  hydrate: ->
    rootName = @getRootElementName @hash
    hash = @unfolded @hash
    @exportCollections @getHydratedCollections hash
    @exportProperties @getHydratedProperties hash

  #
  # Exports properties to target API node
  #
  # @param properties [Object] properties to export
  #
  exportProperties: (properties) ->
    @target.properties = properties

  #
  # Exports specified collections to target.
  # By default uses instance target.
  #
  # @overload exportCollections(collections)
  #   @param collections [Object<OVirtCollection>] hash of collections
  #
  # @overload exportCollections(collections, target)
  #   @param collections [Object<OVirtCollection>] hash of collections
  #   @param target [OVirtApiNode] target API node
  #
  exportCollections: (collections, target) ->
    target = @target unless target
    target.collections = collections

  #
  # Tests whether specified subject is a link to collection.
  #
  # @param subject [Object, Array] tested subject
  #
  # @return [Boolean] whether specified subject is a collection hash
  #
  isCollectionLink: (subject) ->
    return no unless @isLink subject
    subject = @unfolded subject
    subject.rel? and not @isResourceLink subject

  #
  # Tests whether specified subject is a link to resource or collection.
  #
  # @param subject [Object, Array] tested subject
  #
  # @return [Boolean] whether specified subject is a link
  #
  isLink: (subject) ->
    subject = @unfolded subject
    return no unless subject
    (subject.rel? or subject.id?) and subject.href?

  #
  # Tests whether specified subject is a link to resource.
  #
  # @param subject [Object] tested subject
  #
  # @return [Boolean] whether specified subject is a resource link
  #
  isResourceLink: (subject) ->
    return no unless @isLink subject
    subject = @unfolded subject
    return no unless subject
    /\w+-\w+-\w+-\w+-\w+$/.test subject.href


  #
  # Tests whether specified subject is a resource hash representation.
  #
  # @param subject [Object] tested subject
  #
  # @return [Boolean] whether specified subject is a resource link
  #
  isResource: (subject) ->



  #
  # Tests if value is a valid search option "rel" attribute.
  #
  # Rels with leading slashes treated as invalid.
  #
  # @param rel [String] link "rel" attribute
  #
  # @return [Boolean]
  #
  isSearchOption: (rel) ->
    /^\w+\/search$/.test rel

  #
  # Tests if specified value is a property key.
  #
  # @param name [String] supject name
  #
  # @return [Boolean]
  #
  isProperty: (name) ->
    (OVirtResponseHydrator.SPECIAL_PROPERTIES.indexOf name) < 0

  #
  # Returns href base for specified search pattern.
  #
  # @param href [String] serch option link "href" attribute
  #
  # @return [String] search href base or undefined
  #
  getSearchHrefBase: (href) ->
    matches = href.match /^([\w\/;{}=]+\?search=)/
    matches[1] if _.isArray(matches) and matches.length is 2

  #
  # Extracts first element of the collection search link 'rel' atribute.
  #
  # @param rel [String] rel attribute of the collection search link
  #
  # @return [String]
  #
  # @private
  #
  _getSearchOptionCollectionName: (rel) ->
    matches = rel.match /^(\w+)\/search$/
    matches[1] if _.isArray(matches) and matches.length is 2

  #
  # Extracts special object collection name from the 'rel' attribute.
  #
  # @param rel [String] rel attribute of the special object link
  #
  # @return [String]
  #
  # @private
  #
  _getSpecialObjectCollection: (rel) ->
    matches = rel.match /([\w\/]+)\/\w+$/
    matches[1] if _.isArray(matches) and matches.length is 2

  #
  # Extracts special object name from the 'rel' attribute.
  #
  # @param rel [String] rel attribute of the special object link
  #
  # @return [String]
  #
  # @private
  #
  _getSpecialObjectName: (rel) ->
    matches = rel.match /[\w\/]+\/(\w+)$/
    matches[1] if _.isArray(matches) and matches.length is 2

  #
  # Passes searchabilities to exact collections.
  #
  # @param collections [Object<OVirtCollection>] collections hash
  # @param searchabilities [Object] search options for selected collections
  #
  # @private
  #
  _makeCollectionsSearchabe: (collections, searchabilities) ->
    for key of searchabilities
      collections[key].searchOptions =
        href: searchabilities[key].href

  #
  # Adds special objects to corresponding collections.
  #
  # @param collections [Object<OVirtCollection>] collections hash
  # @param specialities [Object] collections special objects
  #
  # @private
  #
  _addSpecialObjects: (collections, specialities) ->
    try
      for object in specialities[0].link
        @_addSpecialObject collections, _.clone object

  #
  # Adds special object to exact collections.
  #
  # @param collections [OVirtCollection] collections hash
  # @param specialities [Object] collection special objects
  #
  # @private
  #
  _addSpecialObject: (collections, object) ->
    object = @_mergeAttributes object
    collection = @_getSpecialObjectCollection object.rel
    name = @_getSpecialObjectName object.rel

    if collections[collection]?
      collections[collection].addSpecialObject name, object.href

  #
  # Returns collections special objects of response hash.
  #
  # @param hash [Object]
  #
  # @return [Object]
  #
  # @private
  #
  _getSpecialObjects: (hash) ->
    hash[OVirtResponseHydrator.SPECIAL_OBJECTS]

  #
  # Returns a hash of top-level collections with properly setup search
  # capabilities and special objects.
  #
  # @param hash [Object] hash
  #
  # @return [Object<OVirtCollection>] hash of collections
  #
  getHydratedCollections: (hash) ->
    {collections, searchabilities} = @_findCollections hash

    @_setupCollections collections
    @_makeCollectionsSearchabe collections, searchabilities
    @_addSpecialObjects collections, @_getSpecialObjects hash

    collections

  #
  # Replaces collections property hash with corresponding collection instances.
  #
  # @param hash [Object<String>] hash
  #
  # @return [Object<OVirtCollection>] hash of collections instances
  #
  # @private
  #
  _setupCollections: (collections) ->
    for name, href of collections
      collections[name] = new OVirtCollection name, href

  #
  # Returns top-level collections an their search options.
  #
  # The result is a hash with two properties: colections and searchabilities.
  #
  # @param hash [Object] hash
  #
  # @return [Object] hash of collections and their search options
  #
  # @private
  #
  _findCollections: (hash) ->
    list = hash[OVirtResponseHydrator.LINK_PROPERTY]
    collections = {}
    searchabilities = {}

    list = [] unless _.isArray list

    for entry in list when @isCollectionLink entry
      entry = @_mergeAttributes _.clone entry
      name = entry.rel
      if @isSearchOption name
        name = @_getSearchOptionCollectionName name
        searchabilities[name] = entry
      else
        collections[name] = entry.href

    collections: collections
    searchabilities: searchabilities

  #
  # Return a hash of hydrated properties.
  #
  # @param hash [Object] hash
  #
  # @return [Object] hash of hydrated properties
  #
  getHydratedProperties: (hash) ->
    properties = {}

    for name, value of hash when @isProperty name
      properties[name] = @_hydrateProperty value

    @_mergeAttributes properties

    properties

  #
  # Hydrates specified array.
  # Unfolds singular array element.
  #
  # @param value [Array]
  #
  # @return [Array,mixed]
  #
  # @private
  #
  _hydrateArray: (subject) ->
    @_hydrateProperty entry for entry in subject

  #
  # Merges attributes into element.
  # Attribute key is defined by {.ATTRIBUTE_KEY}
  #
  # @param subject [Object]
  #
  # @return [Object]
  #
  # @private
  #
  _mergeAttributes: (subject) ->
    key = OVirtResponseHydrator.ATTRIBUTE_KEY
    _.merge subject, @_getAttributes subject
    delete subject[key]

    subject

  #
  # Returns element attributes.
  # Attribute key is defined by {.ATTRIBUTE_KEY}
  #
  # @param subject [Object]
  #
  # @return [Object]
  #
  # @private
  #
  _getAttributes: (subject) ->
    key = OVirtResponseHydrator.ATTRIBUTE_KEY
    if subject[key]?
      subject[key]
    else
      {}

  #
  # Returns whether element has attributes.
  #
  # @param subject [Object]
  #
  # @return [Boolean]
  #
  # @private
  #
  _hasAttributes: (subject) ->
    if not (_.isObject subject) or _.isArray subject
      return undefined

    keys = Object.keys subject
    _.contains keys, OVirtResponseHydrator.ATTRIBUTE_KEY

  #
  # Returns whether element has children.
  # Attributes are not considered as a children.
  #
  # @param subject [Object]
  #
  # @return [Boolean]
  #
  # @private
  #
  _hasChildElements: (subject) ->
    if not (_.isObject subject) or _.isArray subject
      return undefined

    keys = Object.keys subject
    count = keys.length
    count-- if _.contains keys, OVirtResponseHydrator.ATTRIBUTE_KEY

    count > 0

  #
  # Retrieves element's children.
  # Attributes are not considered as a children.
  #
  # @param subject [Object]
  #
  # @return [Object]
  #
  # @private
  #
  _getElementChildren: (subject) ->
    if not (_.isObject subject) or _.isArray subject
      return undefined

    _.omit subject, OVirtResponseHydrator.ATTRIBUTE_KEY


  #
  # Removes special properties defined in {.SPECIAL_PROPERTIES}.
  #
  # @param value [Object]
  #
  # @return [Object]
  #
  # @private
  #
  _removeSpecialProperties: (subject) ->
    for key in OVirtResponseHydrator.SPECIAL_PROPERTIES
      delete subject[key]
    subject

  #
  # Hydrates specified hash.
  #
  # @param value [Object]
  #
  # @return [mixed]
  #
  # @private
  #
  _hydrateHash: (subject) ->
    subject = @_mergeAttributes _.clone subject
    for name, value of subject
      subject[name] = @_hydrateProperty value
    @_removeSpecialProperties subject

  #
  # Hydrates specified value.
  #
  # @param value [mixed]
  #
  # @return [mixed]
  #
  # @private
  #
  _hydrateProperty: (value) ->
    if _.isArray value
      @_hydrateArray value
    else if @isResourceLink value
      @_setupResourceLink value
    else if @isResource value
      @_setupResource value
    else if _.isObject value
      @_hydrateHash value
    else
      value


  #
  # Converts hash to resource.
  #
  # @param value [Object]
  #
  # @return [<OVirtResource>]
  #
  # @private
  #
  _setupResourceLink: (hash) ->
    new OVirtResource @_mergeAttributes _.clone hash


  #
  # Returns the name of the hash's root key if exist.
  #
  # @overload getRootElementName()
  #   Uses instance hash property as an input value.
  #
  # @overload getRootElementName(hash)
  #   Accepts hash as an argument
  #   @param hash [Object] hash
  #
  # @return [String] hash root key or undefined
  #
  getRootElementName: (hash) ->
    hash = @_hash unless hash?
    return undefined unless _.isObject hash
    keys = Object.keys(hash)
    if keys.length is 1 and not _.isArray hash[keys[0]]
      keys[0]
    else
      undefined

  #
  # Returns the value of the hash root element if existed.
  #
  # @overload unfolded()
  #   Uses instance hash property as an input value.
  #
  # @overload unfolded(hash)
  #   Accepts hash as an argument
  #   @param hash [mixed] hash
  #
  # @return [mixed] hash root key or undefined
  #
  unfolded: (hash) ->
    hash = @_hash unless hash?
    return undefined unless hash?
    rootName = @getRootElementName hash
    hash = hash[rootName] if rootName
    hash


module.exports = OVirtResponseHydrator