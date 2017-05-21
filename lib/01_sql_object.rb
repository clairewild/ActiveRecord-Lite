require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'

class SQLObject
  def self.columns
    if @columns.nil?
      cols = DBConnection.execute2("SELECT * FROM #{table_name}")
      @columns = cols[0].map { |col_name| col_name.to_sym }
    end
    @columns
  end

  def self.finalize!
    columns.each do |col_name|
      define_method(col_name) { attributes[col_name] }

      define_method("#{col_name}=") do |value|
        attributes[col_name] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.to_s.tableize
  end

  def self.all
    data = DBConnection.execute("SELECT #{table_name}.* FROM #{table_name}")
    parse_all(data)
  end

  def self.parse_all(results)
    models = []
    results.each do |datum|
      models << self.new(datum)
    end
    models
  end

  def self.find(id)
    data = DBConnection.execute("SELECT #{table_name}.* FROM #{table_name} WHERE id = #{id}")
    parse_all(data).first
  end

  def initialize(params = {})
    cols = self.class.columns
    params.each do |attr_name, value|
      raise "unknown attribute '#{attr_name}'" unless cols.include?(attr_name.to_sym)
      send("#{attr_name}=", value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |val| self.send(val) }
  end

  def insert
    cols = self.class.columns
    q_marks = (["?"] * cols.length).join(", ")
    col_names = cols.join(", ")

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{q_marks})
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  def update
    set_line = self.class.columns.map { |col_sym| "#{col_sym.to_s} = ?" }.join(", ")

    DBConnection.execute(<<-SQL, *attribute_values, id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set_line}
      WHERE
        id = ?
    SQL
  end

  def save
    id.nil? ? insert : update
  end
end
