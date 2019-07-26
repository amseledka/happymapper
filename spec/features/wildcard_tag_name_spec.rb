# frozen_string_literal: true

require 'spec_helper'

module GenericBase
  class Base
    include Comparable
    include HappyMapper

    def initialize(params = {})
      @name = params[:name]
      @href = params[:href]
      @other = params[:other]
    end

    tag '*'
    attribute :name, String
    attribute :href, String
    attribute :other, String

    def <=>(other)
      result = name <=> other.name
      return result unless result == 0

      result = href <=> other.href
      return result unless result == 0

      self.other <=> other.other
    end
  end

  class Sub
    include HappyMapper
    tag 'subelement'
    has_one :jello, Base, tag: 'jello'
  end

  class Root
    include HappyMapper
    tag 'root'
    element :description, String
    has_many :blargs, Base, tag: 'blarg', xpath: '.'
    has_many :jellos, Base, tag: 'jello', xpath: '.'
    has_many :subjellos, Base, xpath: 'subelement/.', tag: 'jello', read_only: true
    has_one :sub_element, Sub
  end
end

RSpec.describe 'Wildcard Root Tag', type: :feature do
  let(:generic_class_xml) do
    <<~XML
      <root>
        <description>some description</description>
        <blarg name='blargname1' href='http://blarg.com'/>
        <blarg name='blargname2' href='http://blarg.com'/>
        <jello name='jelloname' href='http://jello.com'/>
        <subelement>
          <jello name='subjelloname' href='http://ohnojello.com' other='othertext'/>
        </subelement>
      </root>
    XML
  end

  describe "can have generic classes using tag '*'" do
    let(:root) { GenericBase::Root.parse(generic_class_xml) }

    it 'maps different elements to same class' do
      aggregate_failures do
        expect(root.blargs).not_to be_nil
        expect(root.jellos).not_to be_nil
      end
    end

    it 'filters on xpath appropriately' do
      aggregate_failures do
        expect(root.blargs.size).to eq(2)
        expect(root.jellos.size).to eq(1)
        expect(root.subjellos.size).to eq(1)
      end
    end

    def base_with(name, href, other)
      GenericBase::Base.new(name: name, href: href, other: other)
    end

    it 'parses correct values onto generic class' do
      aggregate_failures do
        expect(root.blargs[0]).to eq base_with('blargname1', 'http://blarg.com', nil)
        expect(root.blargs[1]).to eq base_with('blargname2', 'http://blarg.com', nil)
        expect(root.jellos[0]).to eq base_with('jelloname', 'http://jello.com', nil)
        expect(root.subjellos[0]).to eq base_with('subjelloname', 'http://ohnojello.com', 'othertext')
      end
    end

    context 'when converting to xml' do
      let(:xml) { Nokogiri::XML(root.to_xml) }

      def validate_xpath(xpath, name, href, other)
        expect(xml.xpath("#{xpath}/@name").text).to eq name
        expect(xml.xpath("#{xpath}/@href").text).to eq href
        expect(xml.xpath("#{xpath}/@other").text).to eq other
      end

      it 'uses the tag name specified by the parent element' do
        aggregate_failures do
          expect(xml.xpath('/root/description').text).to eq('some description')
          validate_xpath('/root/blarg[1]', 'blargname1', 'http://blarg.com', '')
          validate_xpath('/root/blarg[2]', 'blargname2', 'http://blarg.com', '')
          validate_xpath('/root/jello[1]', 'jelloname', 'http://jello.com', '')
        end
      end

      # TODO: Move to different spec since this has nothing to do with element inheritance
      it "properly respects child tags if tag isn't provided on the element defintion" do
        expect(xml.xpath('root/subelement').size).to eq(1)
      end
    end
  end
end
