require_relative '02_searchable'
require 'active_support/inflector'
require 'byebug'

class AssocOptions
  attr_accessor(
    :foreign_key,
    :class_name,
    :primary_key
  )

  def model_class
    @class_name.constantize
  end

  def table_name
    model_class.table_name
  end
end

class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    @primary_key = :id
    @foreign_key = "#{name}_id".to_sym
    @class_name = name.to_s.camelcase
    options.each do |key, val|
      self.send("#{key}=", val)
    end
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    @primary_key = :id
    @foreign_key = "#{self_class_name.underscore}_id".to_sym
    @class_name = name.to_s.singularize.camelcase
    options.each do |key, val|
      self.send("#{key}=", val)
    end
  end
end

module Associatable
  def belongs_to(name, options = {})
    options = BelongsToOptions.new(name, options)
    self.assoc_options[name] = options

    define_method(name) do
      id = options.primary_key
      foreign_key = self.send(options.foreign_key)
      model_class = options.model_class
      results = model_class.where({ id => foreign_key })

      return nil if results.empty?
      results.first
    end
  end

  def has_many(name, options = {})
    options = HasManyOptions.new(name, self.to_s, options)
    self.assoc_options[name] = options

    define_method(name) do
      id = self.send(options.primary_key)
      foreign_key = options.foreign_key
      model_class = options.model_class
      results = model_class.where({ foreign_key => id })
    end
  end

  def assoc_options
    @assoc_options ||= {}
    @assoc_options
  end
end

class SQLObject
  extend Associatable
end
