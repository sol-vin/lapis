require "yaml"
require "json"
require "jasper"

module Lapis
  module Docs
    alias DocSection = Jasper::DocSection
    alias DocDocument = Jasper::DocDocument
    alias DocTrack = Jasper::DocTrack

    class DocTopicIndex
      include YAML::Serializable

      property id : String
      property title : String
      property summary : String
      property description : String? = nil
      property subtopics : Array(String) = [] of String
    end

    enum Context
      Godot
      Crystal
      Stdlib
      Guide

      def self.parse?(str : String) : Context?
        case str.strip.downcase
        when "gd", "godot"
          Godot
        when "crystal", "cr"
          Crystal
        when "stdlib", "std"
          Stdlib
        when "guide", "docs", "doc", "manual"
          Guide
        else
          nil
        end
      end

      def to_badge : String
        case self
        when Godot   then "GD"
        when Crystal then "CR"
        when Stdlib  then "STD"
        else              "DOC"
        end
      end
    end

    enum SymbolKind
      Class
      Node
      Struct
      Module
      Method
      Property
      Signal
      Constant
      Enum
      Guide

      def to_badge : String
        case self
        when Class    then "CLASS"
        when Node     then "NODE"
        when Struct   then "STRUCT"
        when Module   then "MODULE"
        when Method   then "METHOD"
        when Property then "PROP"
        when Signal   then "SIGNAL"
        when Constant then "CONST"
        when Enum     then "ENUM"
        else               "GUIDE"
        end
      end
    end

    struct DocParam
      include JSON::Serializable
      getter name : String
      getter type_str : String
      getter default_value : String?
      getter description : String

      def initialize(@name : String, @type_str : String, @default_value : String? = nil, @description : String = "")
      end
    end

    struct DocSymbol
      include JSON::Serializable

      getter context : Context
      getter kind : SymbolKind
      getter parent_name : String?
      getter name : String
      getter full_query : String
      getter signature : String
      getter return_type : String?
      getter summary : String
      getter description : String
      getter inheritance : Array(String)
      getter file_path : String?
      getter line_number : Int32?
      getter params : Array(DocParam)
      getter tags : Array(String)

      def initialize(
        @context : Context,
        @kind : SymbolKind,
        @name : String,
        @full_query : String,
        @signature : String,
        @summary : String,
        @description : String,
        @parent_name : String? = nil,
        @return_type : String? = nil,
        @inheritance = [] of String,
        @file_path : String? = nil,
        @line_number : Int32? = nil,
        @params = [] of DocParam,
        @tags = [] of String
      )
      end
    end
  end
end
