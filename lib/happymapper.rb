# frozen_string_literal: true

require 'nokogiri'
require 'date'
require 'time'
require 'happymapper/version'
require 'happymapper/anonymous_mapper'

module HappyMapper
  class Boolean; end

  class XmlContent; end

  def self.parse(xml_content)
    AnonymousMapper.new.parse(xml_content)
  end

  def self.included(base)
    if base.superclass <= HappyMapper
      base.instance_eval do
        @attributes =
          superclass.instance_variable_get(:@attributes).dup
        @elements =
          superclass.instance_variable_get(:@elements).dup
        @registered_namespaces =
          superclass.instance_variable_get(:@registered_namespaces).dup
        @wrapper_anonymous_classes =
          superclass.instance_variable_get(:@wrapper_anonymous_classes).dup
      end
    else
      base.instance_eval do
        @attributes = {}
        @elements = {}
        @registered_namespaces = {}
        @wrapper_anonymous_classes = {}
      end
    end

    base.extend ClassMethods
  end

  module ClassMethods
    #
    # The xml has the following attributes defined.
    #
    # @example
    #
    #     "<country code='de'>Germany</country>"
    #
    #     # definition of the 'code' attribute within the class
    #     attribute :code, String
    #
    # @param [Symbol] name the name of the accessor that is created
    # @param [String,Class] type the class name of the name of the class whcih
    #     the object will be converted upon parsing
    # @param [Hash] options additional parameters to send to the relationship
    #
    def attribute(name, type, options = {})
      attribute = Attribute.new(name, type, options)
      @attributes[name] = attribute
      attr_accessor attribute.method_name.intern
    end

    #
    # The elements defined through {#attribute}.
    #
    # @return [Array<Attribute>] a list of the attributes defined for this class;
    #     an empty array is returned when there have been no attributes defined.
    #
    def attributes
      @attributes.values
    end

    #
    # Register a namespace that is used to persist the object namespace back to
    # XML.
    #
    # @example
    #
    #     register_namespace 'prefix', 'http://www.unicornland.com/prefix'
    #
    #     # the output will contain the namespace defined
    #
    #     "<outputXML xmlns:prefix="http://www.unicornland.com/prefix">
    #     ...
    #     </outputXML>"
    #
    # @param [String] name the xml prefix
    # @param [String] href url for the xml namespace
    #
    def register_namespace(name, href)
      @registered_namespaces.merge!(name => href)
    end

    #
    # An element defined in the XML that is parsed.
    #
    # @example
    #
    #     "<address location='home'>
    #        <city>Oldenburg</city>
    #      </address>"
    #
    #     # definition of the 'city' element within the class
    #
    #     element :city, String
    #
    # @param [Symbol] name the name of the accessor that is created
    # @param [String,Class] type the class name of the name of the class whcih
    #     the object will be converted upon parsing
    # @param [Hash] options additional parameters to send to the relationship
    #
    def element(name, type, options = {})
      element = Element.new(name, type, options)
      attr_accessor element.method_name.intern unless @elements[name]
      @elements[name] = element
    end

    #
    # The elements defined through {#element}, {#has_one}, and {#has_many}.
    #
    # @return [Array<Element>] a list of the elements contained defined for this
    #     class; an empty array is returned when there have been no elements
    #     defined.
    #
    def elements
      @elements.values
    end

    #
    # The value stored in the text node of the current element.
    #
    # @example
    #
    #     "<firstName>Michael Jackson</firstName>"
    #
    #     # definition of the 'firstName' text node within the class
    #
    #     content :first_name, String
    #
    # @param [Symbol] name the name of the accessor that is created
    # @param [String,Class] type the class name of the name of the class whcih
    #     the object will be converted upon parsing. By Default String class will be taken.
    # @param [Hash] options additional parameters to send to the relationship
    #
    def content(name, type = String, options = {})
      @content = TextNode.new(name, type, options)
      attr_accessor @content.method_name.intern
    end

    #
    # Sets the object to have xml content, this will assign the XML contents
    # that are parsed to the attribute accessor xml_content. The object will
    # respond to the method #xml_content and will return the XML data that
    # it has parsed.
    #
    def has_xml_content
      attr_accessor :xml_content
    end

    #
    # The object has one of these elements in the XML. If there are multiple,
    # the last one will be set to this value.
    #
    # @param [Symbol] name the name of the accessor that is created
    # @param [String,Class] type the class name of the name of the class whcih
    #     the object will be converted upon parsing
    # @param [Hash] options additional parameters to send to the relationship
    #
    # @see #element
    #
    def has_one(name, type, options = {})
      element name, type, { single: true }.merge(options)
    end

    #
    # The object has many of these elements in the XML.
    #
    # @param [Symbol] name the name of accessor that is created
    # @param [String,Class] type the class name or the name of the class which
    #     the object will be converted upon parsing.
    # @param [Hash] options additional parameters to send to the relationship
    #
    # @see #element
    #
    def has_many(name, type, options = {})
      element name, type, { single: false }.merge(options)
    end

    #
    # The list of registered after_parse callbacks.
    #
    def after_parse_callbacks
      @after_parse_callbacks ||= []
    end

    #
    # Register a new after_parse callback, given as a block.
    #
    # @yield [object] Yields the newly-parsed object to the block after parsing.
    #     Sub-objects will be already populated.
    def after_parse(&block)
      after_parse_callbacks.push(block)
    end

    #
    # Specify a namespace if a node and all its children are all namespaced
    # elements. This is simpler than passing the :namespace option to each
    # defined element.
    #
    # @param [String] namespace the namespace to set as default for the class
    #     element.
    #
    def namespace(namespace = nil)
      @namespace = namespace if namespace
      @namespace if defined? @namespace
    end

    #
    # @param [String] new_tag_name the name for the tag
    #
    def tag(new_tag_name)
      @tag_name = new_tag_name.to_s unless new_tag_name.nil? || new_tag_name.to_s.empty?
    end

    #
    # The name of the tag
    #
    # @return [String] the name of the tag as a string, downcased
    #
    def tag_name
      @tag_name ||= name && name.to_s.split('::')[-1].downcase
    end

    # There is an XML tag that needs to be known for parsing and should be generated
    # during a to_xml.  But it doesn't need to be a class and the contained elements should
    # be made available on the parent class
    #
    # @param [String] name the name of the element that is just a place holder
    # @param [Proc] blk the element definitions inside the place holder tag
    #
    def wrap(name, &blk)
      # Get an anonymous HappyMapper that has 'name' as its tag and defined
      # in '&blk'.  Then save that to a class instance variable for later use
      wrapper = AnonymousWrapperClassFactory.get(name, &blk)
      wrapper_key = wrapper.inspect
      @wrapper_anonymous_classes[wrapper_key] = wrapper

      # Create getter/setter for each element and attribute defined on the anonymous HappyMapper
      # onto this class. They get/set the value by passing thru to the anonymous class.
      passthrus = wrapper.attributes + wrapper.elements
      passthrus.each do |item|
        method_name = item.method_name
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{method_name}                                    # def property
            @#{name} ||=                                        #   @wrapper ||=
              wrapper_anonymous_classes['#{wrapper_key}'].new   #     wrapper_anonymous_classes['#<Class:0x0000555b7d0b9220>'].new
            @#{name}.#{method_name}                             #   @wrapper.property
          end                                                   # end

          def #{method_name}=(value)                            # def property=(value)
            @#{name} ||=                                        #   @wrapper ||=
              wrapper_anonymous_classes['#{wrapper_key}'].new   #     wrapper_anonymous_classes['#<Class:0x0000555b7d0b9220>'].new
            @#{name}.#{method_name} = value                     #   @wrapper.property = value
          end                                                   # end
        RUBY
      end

      has_one name, wrapper
    end

    # The callback defined through {.with_nokogiri_config}.
    #
    # @return [Proc] the proc to pass to Nokogiri to setup parse options. nil if empty.
    #
    attr_reader :nokogiri_config_callback

    # Register a config callback according to the block Nokogori expects when
    # calling Nokogiri::XML::Document.parse().
    #
    # See http://nokogiri.org/Nokogiri/XML/Document.html#method-c-parse
    #
    # @param [Proc] the proc to pass to Nokogiri to setup parse options
    #
    def with_nokogiri_config(&blk)
      @nokogiri_config_callback = blk
    end

    #
    # @param [Nokogiri::XML::Node,Nokogiri:XML::Document,String] xml the XML
    #     contents to convert into Object.
    # @param [Hash] options additional information for parsing.
    #     :single => true if requesting a single object, otherwise it defaults
    #     to retuning an array of multiple items.
    #     :xpath information where to start the parsing
    #     :namespace is the namespace to use for additional information.
    #     :encoding explicitly set the encoding to Nokogiri::XML document
    #
    def parse(xml, options = {})
      # Capture any provided namespaces and merge in any namespaces that have
      # been registered on the object.
      namespaces = options[:namespaces] || {}
      namespaces = namespaces.merge(@registered_namespaces)

      # If the XML specified is an Node then we have what we need.
      if xml.is_a?(Nokogiri::XML::Node) && !xml.is_a?(Nokogiri::XML::Document)
        node = xml
      else

        unless xml.is_a?(Nokogiri::XML::Document)
          # Attempt to parse the xml value with Nokogiri XML as a document
          # and select the root element
          encoding = options[:encoding]
          xml = Nokogiri::XML(
            xml, nil, encoding,
            Nokogiri::XML::ParseOptions::STRICT,
            &nokogiri_config_callback
          )
        end
        # Now xml is certainly an XML document: Select the root node of the document
        node = xml.root

        # merge any namespaces found on the xml node into the namespace hash
        namespaces = namespaces.merge(xml.collect_namespaces)

        # if the node name is equal to the tag name then the we are parsing the
        # root element and that is important to record so that we can apply
        # the correct xpath on the elements of this document.

        root = node.name == tag_name
      end

      # If the :single option has been specified or we are at the root element
      # then we are going to return a single element or nil if no nodes are found
      single = root || options[:single]

      # if a namespace has been provided then set the current namespace to it
      # or use the namespace provided by the class
      # or use the 'xmlns' namespace if defined

      namespace = options[:namespace] || self.namespace || namespaces.key?('xmlns') && 'xmlns'

      # from the options grab any nodes present and if none are present then
      # perform the following to find the nodes for the given class

      nodes = options.fetch(:nodes) do
        find_nodes_to_parse(options, namespace, tag_name, namespaces, node, root)
      end

      # Nothing matching found, we can go ahead and return
      return (single ? nil : []) if nodes.empty?

      # If the :limit option has been specified then we are going to slice
      # our node results by that amount to allow us the ability to deal with
      # a large result set of data.

      limit = options[:in_groups_of] || nodes.size

      # If the limit of 0 has been specified then the user obviously wants
      # none of the nodes that we are serving within this batch of nodes.

      return [] if limit == 0

      collection = []

      nodes.each_slice(limit) do |slice|
        part = slice.map do |n|
          parse_node(n, options, namespace, namespaces)
        end

        # If a block has been provided and the user has requested that the objects
        # be handled in groups then we should yield the slice of the objects to them
        # otherwise continue to lump them together

        if block_given? && options[:in_groups_of]
          yield part
        else
          collection += part
        end
      end

      # If we're parsing a single element then we are going to return the first
      # item in the collection. Otherwise the return response is going to be an
      # entire array of items.

      if single
        collection.first
      else
        collection
      end
    end

    # @private
    def defined_content
      @content if defined? @content
    end

    private

    def find_nodes_to_parse(options, namespace, tag_name, namespaces, node, root)
      # when at the root use the xpath '/' otherwise use a more gready './/'
      # unless an xpath has been specified, which should overwrite default
      # and finally attach the current namespace if one has been defined
      #

      xpath = if options[:xpath]
                options[:xpath].to_s.sub(%r{([^/])$}, '\1/')
              elsif root
                '/'
              else
                './/'
              end
      if namespace
        return [] unless namespaces.find { |name, _url| ["xmlns:#{namespace}", namespace].include? name }

        xpath += "#{namespace}:"
      end

      nodes = []

      # when finding nodes, do it in this order:
      # 1. specified tag if one has been provided
      # 2. name of element
      # 3. tag_name (derived from class name by default)

      # If a tag has been provided we need to search for it.

      if options.key?(:tag)
        nodes = node.xpath(xpath + options[:tag].to_s, namespaces)
      else

        # This is the default case when no tag value is provided.
        # First we use the name of the element `items` in `has_many items`
        # Second we use the tag name which is the name of the class cleaned up

        [options[:name], tag_name].compact.each do |xpath_ext|
          nodes = node.xpath(xpath + xpath_ext.to_s, namespaces)
          break if nodes && !nodes.empty?
        end

      end

      nodes
    end

    def parse_node(node, options, namespace, namespaces)
      # If an existing HappyMapper object is provided, update it with the
      # values from the xml being parsed.  Otherwise, create a new object

      obj = options[:update] || new

      attributes.each do |attr|
        value = attr.from_xml_node(node, namespace, namespaces)
        value = attr.default if value.nil?
        obj.send("#{attr.method_name}=", value)
      end

      elements.each do |elem|
        obj.send("#{elem.method_name}=", elem.from_xml_node(node, namespace, namespaces))
      end

      if (content = defined_content)
        obj.send("#{content.method_name}=", content.from_xml_node(node, namespace, namespaces))
      end

      # If the HappyMapper class has the method #xml_value=,
      # attr_writer :xml_value, or attr_accessor :xml_value then we want to
      # assign the current xml that we just parsed to the xml_value

      if obj.respond_to?(:xml_value=)
        obj.xml_value = node.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
      end

      # If the HappyMapper class has the method #xml_content=,
      # attr_write :xml_content, or attr_accessor :xml_content then we want to
      # assign the child xml that we just parsed to the xml_content

      if obj.respond_to?(:xml_content=)
        node = node.children if node.respond_to?(:children)
        obj.xml_content = node.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
      end

      # Call any registered after_parse callbacks for the object's class

      obj.class.after_parse_callbacks.each { |callback| callback.call(obj) }

      # collect the object that we have created

      obj
    end
  end

  # Set all attributes with a default to their default values
  def initialize
    super
    self.class.attributes.reject { |attr| attr.default.nil? }.each do |attr|
      send("#{attr.method_name}=", attr.default)
    end
  end

  #
  # Create an xml representation of the specified class based on defined
  # HappyMapper elements and attributes. The method is defined in a way
  # that it can be called recursively by classes that are also HappyMapper
  # classes, allowg for the composition of classes.
  #
  # @param [Nokogiri::XML::Builder] builder an instance of the XML builder which
  #     is being used when called recursively.
  # @param [String] default_namespace The name of the namespace which is the
  #     default for the xml being produced; this is the namespace of the
  #     parent
  # @param [String] namespace_override The namespace specified with the element
  #     declaration in the parent. Overrides the namespace declaration in the
  #     element class itself when calling #to_xml recursively.
  # @param [String] tag_from_parent The xml tag to use on the element when being
  #     called recursively.  This lets the parent doc define its own structure.
  #     Otherwise the element uses the tag it has defined for itself.  Should only
  #     apply when calling a child HappyMapper element.
  #
  # @return [String,Nokogiri::XML::Builder] return XML representation of the
  #      HappyMapper object; when called recursively this is going to return
  #      and Nokogiri::XML::Builder object.
  #
  def to_xml(builder = nil, default_namespace = nil, namespace_override = nil,
             tag_from_parent = nil)

    #
    # If to_xml has been called without a passed in builder instance that
    # means we are going to return xml output. When it has been called with

    # a builder instance that means we most likely being called recursively
    # and will return the end product as a builder instance.
    #
    unless builder
      write_out_to_xml = true
      builder = Nokogiri::XML::Builder.new
    end

    attributes = collect_writable_attributes

    #
    # If the object we are serializing has a namespace declaration we will want
    # to use that namespace or we will use the default namespace.
    # When neither are specifed we are simply using whatever is default to the
    # builder
    #
    namespace_name = namespace_override || self.class.namespace || default_namespace

    #
    # Create a tag in the builder that matches the class's tag name unless a tag was passed
    # in a recursive call from the parent doc.  Then append
    # any attributes to the element that were defined above.
    #
    builder.send("#{tag_from_parent || self.class.tag_name}_", attributes) do |xml|
      register_namespaces_with_builder(builder)

      xml.parent.namespace =
        builder.doc.root.namespace_definitions.find { |x| x.prefix == namespace_name }

      #
      # When a content has been defined we add the resulting value
      # the output xml
      #
      if (content = self.class.defined_content) && !content.options[:read_only]
        value = send(content.name)
        value = apply_on_save_action(content, value)

        builder.text(value)
      end

      #
      # for every define element (i.e. has_one, has_many, element) we are
      # going to persist each one
      #
      self.class.elements.each do |element|
        element_to_xml(element, xml, default_namespace)
      end
    end

    # Write out to XML, this value was set above, based on whether or not an XML
    # builder object was passed to it as a parameter. When there was no parameter
    # we assume we are at the root level of the #to_xml call and want the actual
    # xml generated from the object. If an XML builder instance was specified
    # then we assume that has been called recursively to generate a larger
    # XML document.
    write_out_to_xml ? builder.to_xml.force_encoding('UTF-8') : builder
  end

  # Parse the xml and update this instance. This does not update instances
  # of HappyMappers that are children of this object.  New instances will be
  # created for any HappyMapper children of this object.
  #
  # Params and return are the same as the class parse() method above.
  def parse(xml, options = {})
    self.class.parse(xml, options.merge!(update: self))
  end

  # Factory for creating anonmyous HappyMappers
  class AnonymousWrapperClassFactory
    def self.get(name, &blk)
      Class.new do
        include HappyMapper
        tag name
        instance_eval(&blk)
      end
    end
  end

  private

  #
  # If the item defines an on_save lambda/proc or value that maps to a method
  # that the class has defined, then call it with the value as a parameter.
  # This allows for operations to be performed to convert the value to a
  # specific value to be saved to the xml.
  #
  def apply_on_save_action(item, value)
    if (on_save_action = item.options[:on_save])
      if on_save_action.is_a?(Proc)
        value = on_save_action.call(value)
      elsif respond_to?(on_save_action)
        value = send(on_save_action, value)
      end
    end
    value
  end

  #
  # Find the attributes for the class and collect them into a Hash structure
  #
  def collect_writable_attributes
    #
    # Find the attributes for the class and collect them into an array
    # that will be placed into a Hash structure
    #
    attributes = self.class.attributes.collect do |attribute|
      #
      # If an attribute is marked as read_only then we want to ignore the attribute
      # when it comes to saving the xml document; so we will not go into any of
      # the below process
      #
      next if attribute.options[:read_only]

      value = send(attribute.method_name)
      value = nil if value == attribute.default

      #
      # Apply any on_save lambda/proc or value defined on the attribute.
      #
      value = apply_on_save_action(attribute, value)

      #
      # Attributes that have a nil value should be ignored unless they explicitly
      # state that they should be expressed in the output.
      #
      next if value.nil? && !attribute.options[:state_when_nil]

      attribute_namespace = attribute.options[:namespace]
      ["#{attribute_namespace ? "#{attribute_namespace}:" : ''}#{attribute.tag}", value]
    end.compact

    attributes.to_h
  end

  #
  # Add all the registered namespaces to the builder's root element.
  # When this is called recursively by composed classes the namespaces
  # are still added to the root element
  #
  # However, we do not want to add the namespace if the namespace is 'xmlns'
  # which means that it is the default namespace of the code.
  #
  def register_namespaces_with_builder(builder)
    return unless self.class.instance_variable_get(:@registered_namespaces)

    self.class.instance_variable_get(:@registered_namespaces).sort.each do |name, href|
      name = nil if name == 'xmlns'
      builder.doc.root.add_namespace(name, href)
    end
  end

  # Persist a single nested element as xml
  def element_to_xml(element, xml, default_namespace)
    #
    # If an element is marked as read only do not consider at all when
    # saving to XML.
    #
    return if element.options[:read_only]

    tag = element.tag || element.name

    #
    # The value to store is the result of the method call to the element,
    # by default this is simply utilizing the attr_accessor defined. However,
    # this allows for this method to be overridden
    #
    value = send(element.name)

    #
    # Apply any on_save action defined on the element.
    #
    value = apply_on_save_action(element, value)

    #
    # To allow for us to treat both groups of items and singular items
    # equally we wrap the value and treat it as an array.
    #
    values = if value.respond_to?(:to_ary) && !element.options[:single]
               value.to_ary
             else
               [value]
             end

    values.each do |item|
      if item.is_a?(HappyMapper)

        #
        # Other items are convertable to xml through the xml builder
        # process should have their contents retrieved and attached
        # to the builder structure
        #
        item.to_xml(xml, self.class.namespace || default_namespace,
                    element.options[:namespace],
                    element.options[:tag] || nil)

      elsif !item.nil? || element.options[:state_when_nil]

        item_namespace = element.options[:namespace] || self.class.namespace || default_namespace

        #
        # When a value exists or the tag should always be emitted,
        # we should append the value for the tag
        #
        if item_namespace
          xml[item_namespace].send("#{tag}_", item.to_s)
        else
          xml.send("#{tag}_", item.to_s)
        end
      end
    end
  end

  def wrapper_anonymous_classes
    self.class.instance_variable_get(:@wrapper_anonymous_classes)
  end
end

require 'happymapper/supported_types'
require 'happymapper/item'
require 'happymapper/attribute'
require 'happymapper/element'
require 'happymapper/text_node'
