require 'csv'

class MySqliteRequest
  def initialize
    @args_from_cli = false
    @column_titles = []
    @delete_request = false
    @file_name = nil
    @insert_values = []
    @join_request = []
    @join_table_array = []
    @join_column_titles = []
    @join_table_data_hash_array = []
    @left_table_column_name_adjusted = false
    @select_request = []
    @sort_query = []
    @table_data_arr = []
    @table_data_array_with_hashes = []
    @update_values = []
    @where_query = []
    @where_query_not_match = false
  end

  def table_data_array_to_hash_req(column_titles, table)
    table_data_hash_array_req = []
    table_data_hash_array = table_data_hash_array_req
    id = 0
    table.each do |row|
      hash_req = {}
      hash = hash_req
      hash, id = assign_hash_values_pas(hash, column_titles, row, id)
      table_data_hash_array.push(hash)
    end
    column_titles_p1 = check_for_id_column_param_a(column_titles)
    column_titles = column_titles_p1
    return table_data_hash_array
  end

  def assign_hash_values_pas(hash, column_titles, row, id)
    id += 1
    hash["id"] = id
    row.each_index do |i|
      row[i] = convert_integer_strings_to_integers_sqlite(row, i)
      hash["#{column_titles[i]}"] = row[i]
    end
    return hash, id
  end

  def convert_integer_strings_to_integers_sqlite(row, i)
    if row[i] && row[i].match?(/\A\d+\z/)
      row[i] = row[i].to_i
    end
    return row[i]
  end

  def check_for_id_column_param_a(column_titles)
    if !column_titles.include?("id")
      column_titles.unshift("id")
    end
    return column_titles
  end

  def args_from_cli
    @args_from_cli = true
    return self
  end

  def from(table_name)
   # From Implement a from method which must be present on each request. From will take a parameter and it will be the name of the table. (technically a table_name is also a filename (.csv))
    @file_name = table_name
    return self
  end

  def select(column_name)
    # Select Implement a where method which will take one argument a string OR an array of string. It will continue to build the request. During the run() you will collect on the result only the columns sent as parameters to select :-).
    if column_name.is_a?(Array)
      @select_request = column_name
    else
      @select_request.push(column_name)
    end
    return self
  end

  def where(column_name, criteria)
      # Where Implement a where method which will take 2 arguments: column_name and value. It will continue to build the request. During the run() you will filter the result which match the value.
    if !criteria.is_a?(Integer) && criteria.match?(/\A\d+\z/)
      criteria = criteria.to_i
    end
    @where_query.push(column_name)
    @where_query.push('=')
    @where_query.push(criteria)
    return self
  end

  def where_comparison_operator_param(comparison_operator, i)
    @where_comparison_operator_param = comparison_operator
    @where_query[1 + 3*i] = @where_comparison_operator_param
    return self
  end

  def join(column_on_db_a, filename_db_b, column_on_db_b)
    # Join Implement a join method which will load another filename_db and will join both database on a on column.
    @join_file_name = filename_db_b
    @join_table_array, @join_column_titles, @join_table_data_hash_array = read_table_data_req(@join_file_name, @join_table_array, @join_column_titles, @join_table_data_hash_array)
    @join_request.push(column_on_db_a)
    @join_request.push(column_on_db_b)
    return self
  end

  def order(order = 'ASC', column_name)
    # Order Implement an order method which will received two parameters, order (:asc or :desc) and column_name. It will sort depending on the order base on the column_name.
    @sort_query.push(order)
    @sort_query.push(column_name)
    return self
  end

  def insert(table_name)
    # Insert Implement a method to insert which will receive a table name (filename). It will continue to build the request.
    @file_name = table_name
    puts @file_name
    return self
  end

  def values(data)
    # Values Implement a method to values which will receive data. (a hash of data on format (key => value)). It will continue to build the request. During the run() you do the insert.
    @insert_values = data
    return self
  end

  def update(table_name)
    # Update Implement a method to update which will receive a table name (filename). It will continue to build the request. An update request might be associated with a where request.
    @file_name = table_name
    return self
  end

  def set(data)
    # Set Implement a method to update which will receive data (a hash of data on format (key => value)). It will perform the update of attributes on all matching row. An update request might be associated with a where request.
    @update_values = data
    return self
  end

  def delete
    # Delete Implement a delete method. It set the request to delete on all matching row. It will continue to build the request. An delete request might be associated with a where request.
    @delete_request = true
    return self
  end

  def invalid_file()
        puts "Error: Invalid File"
  end

  def run
    if !File.file?(@file_name)
        invalid_file()
      return self
    end
    @table_data_arr, @column_titles, @table_data_array_with_hashes = read_table_data_req(@file_name, @table_data_arr, @column_titles, @table_data_array_with_hashes)
    join_filter_sort_select_table_req()
    update_delete_insert_table_sqlite()
    display_table_data_req()
    return
  end

  def read_table_data_req(file_name, array_table, column_titles, hash_table)
    array_table_po = CSV.parse(File.read(file_name))
    array_table = array_table_po
    column_titles = array_table.shift
    hash_table = table_data_array_to_hash_req(column_titles, array_table)
    return array_table, column_titles, hash_table
  end

  def join_filter_sort_select_table_req
    if @join_request.length > 0
        join_tables_set()
      save_updated_table_to_file_use(@new_join_table_file, "w+")
    end
    if @where_query.length > 0 && !(@update_values.length > 0) && !@delete_request
        filter_table_by_where_condition_req()
    end
    if @sort_query.length > 0
        sort_table_dss()
    end
    if @select_request[0] != '*' && @select_request.length > 1
        filter_table_by_select_req()
    end
  end

  def update_delete_insert_table_sqlite
    if @update_values.length > 0
        update_values_in_data_table_list()
        save_updated_table_to_file_use(@file_name, "w")
    end
    if @delete_request
        delete_table_value_pop()
        save_updated_table_to_file_use(@file_name, "w")
    end
    if @insert_values.length > 0
        insert_values_in_table_set()
        save_updated_table_to_file_use(@file_name, "w")
    end
  end

  def display_table_data_req
    if @select_request.length > 0
      if @args_from_cli
        print_table_sen()
      else
        puts "#{@table_data_array_with_hashes}"
      end
    end
  end

# display table data
  def print_table_sen()
    if @select_request[0] == '*'
      @select_request = @column_titles
    end
    print_column_titles_k()
    print_row_values_p()
  end

  def print_column_titles_k()
    @select_request.each_with_index do |column, i|
      if i == @select_request.length - 1
        print "#{column}"
      else
      print "#{column}|"
      end
    end
    print "\n"
  end

  def print_row_values_p()
    @table_data_array_with_hashes.each do |row|
      @select_request.each_with_index do |column, i|
        if i == @select_request.length - 1
          print "#{row["#{column}"]}"
        else
          print "#{row["#{column}"]}|"
        end
      end
      print "\n"
    end
  end

# update, delete, insert
  # update
  def update_values_in_data_table_list()
    update_keys = @update_values.keys
    if @where_query.length > 0
      @table_data_array_with_hashes.each do |row|
        where_column_value, where_comparison_operator_param, where_criteria_value = prepare_where_query_lip(0, row)
        if compare(where_comparison_operator_param, where_column_value, where_criteria_value)
          update_keys.each do |key|
            row["#{key}"] = @update_values["#{key}"]
          end
        end
      end
    else
      @table_data_array_with_hashes.each do |row|
        update_keys.each do |key|
          row["#{key}".to_sym] = @update_values["#{key}"]
        end
      end
    end
  end

  # delete
  def delete_table_value_pop()
    if @where_query.length > 0
      @table_data_array_with_hashes.reverse_each do |row|
        @where_query_not_match = check_where_query_sqlite(row)
        if @where_query_not_match
          next
        end
        @table_data_array_with_hashes.delete(row)
      end
    else # deletes every row
      @table_data_array_with_hashes.reverse_each do |row|
        @table_data_array_with_hashes.delete(row)
      end
    end
  end

  # insert
  def insert_values_in_table_set()

    insert_keys = @insert_values.keys

    if !insert_keys.include?("#{"id"}")
      @insert_values["id"] = @table_data_array_with_hashes.length+1
      insert_keys.push("id")
    end

    @column_titles.each do |column|
      if !insert_keys.include?(column.to_sym)
        @insert_values[:"#{column}"] = nil
      end
    end
    @table_data_array_with_hashes.push(@insert_values)
  end

  def save_updated_table_to_file_use(file, mode)
    CSV.open(file, mode) do |csv|
      csv << @column_titles
      @table_data_array_with_hashes.each_with_index do |row, i|
        array_row = convert_hash_to_array_arr(row, i)
        csv << array_row
      end
    end
  end

  def convert_hash_to_array_arr(hash, i)
    array_req = []
    array = array_req
    @column_titles.each do |value|
      array.push(hash["#{value}"])
    end
    return array
  end

# join, filter, sort, select
  # join
  def join_tables_set()
    joined_table_req = []
    joined_table=joined_table_req
    left_table_column, right_table_column = remove_file_extension_from_join_value_users()
    @table_data_array_with_hashes.each do |row|
      @left_table_column_name_adjusted = false
      left_table_value = row["#{left_table_column}"]
      @join_table_data_hash_array.each do |join_table_row|
        temp_table_req = compare_and_join_tables_req(row, left_table_value, join_table_row, right_table_column, joined_table)
        temp_table = temp_table_req
        joined_table = temp_table
      end
    end
    @table_data_array_with_hashes = joined_table
    prepare_joined_table_il()
  end

  def remove_file_extension_from_join_value_users()
    left_table_column = @join_request[0].slice!(@join_request[0].rindex('.')+1..-1)
    right_table_column = @join_request[1].slice!(@join_request[1].rindex('.')+1..-1)
    return left_table_column, right_table_column
  end

  def compare_and_join_tables_req(row, left_table_value, join_table_row, right_table_column, joined_table)
    right_table_value = join_table_row["#{right_table_column}"]
    if left_table_value == right_table_value
      joined_rows = join_rows_let(row, join_table_row)
      joined_table.push(joined_rows)
      @left_table_column_name_adjusted = true
      # break  --- break is only needed if you want to only match left table for one value on right & ignore any other possible matches
    end
    return joined_table
  end

  def join_rows_let(left_row, right_row)

    left_keys = left_row.keys #array of left table keys
    left_key_map = {}

    right_keys = right_row.keys #array of right table keys
    right_key_map = {}

    if !@left_table_column_name_adjusted
      left_keys.each_index do |i|
        left_key_map["#{left_keys[i]}"] = "#{@file_name}.#{left_keys[i]}"
      end
      left_row.transform_keys!{ |k| left_key_map[k]}
    end

    right_keys.each_index do |i|
      right_key_map["#{right_keys[i]}"] = "#{@join_file_name}.#{right_keys[i]}"
    end
    right_row.transform_keys!{ |k| right_key_map[k]}

    joined_rows = left_row.merge(right_row)
    return joined_rows

  end

  def prepare_joined_table_il()
    @new_join_table_file = @file_name + '_join_' + @join_file_name

    @column_titles.each_index do |i|
      @column_titles[i] = "#{@file_name}.#{@column_titles[i]}"
    end

    @join_column_titles.each_index do |i|
      @join_column_titles[i] = "#{@join_file_name}.#{@join_column_titles[i]}"
    end

    @joined_column_titles = @column_titles.concat(@join_column_titles)
    @column_titles = @joined_column_titles
  end

  # filter
  def filter_table_by_where_condition_req()
    @filtered_table = []
    @table_data_array_with_hashes.each do |row|
      @where_query_not_match = check_where_query_sqlite(row)
      if @where_query_not_match
        next
      end
      filtered_hash = {}
      @column_titles.each do |column|
        filtered_hash["#{column}"] = row["#{column}"]
      end
      @filtered_table.push(filtered_hash)
    end
    @table_data_array_with_hashes = @filtered_table

  end

  def prepare_where_query_lip(i, row)
    where_column_value = row["#{@where_query[i]}"]
    where_comparison_operator_param = @where_query[i+1]
    where_criteria_value = @where_query[i+2]
    return where_column_value, where_comparison_operator_param, where_criteria_value
  end

  def check_where_query_sqlite(row)
    @where_query.each_index do |i|
      next if i % 3 != 0
      @where_query_not_match = false
      where_column_value, where_comparison_operator_param, where_criteria_value = prepare_where_query_lip(i, row)
      if !compare(where_comparison_operator, where_column_value, where_criteria_value)
        @where_query_not_match = true
        break
      end
    end
    return @where_query_not_match
  end

  def compare(comparison, a, b)
    case comparison
    when '='
      return a == b
    when'!='
      return a != b
    when '>'
      return a > b
    when '>='
      return a>=b
    when '<'
      return a < b
    when '<='
      return a <= b
    end
  end

  # sort
  def sort_table_dss()

    if @sort_query[0] == 'ASC'
      @table_data_array_with_hashes = @table_data_array_with_hashes.sort_by{|a|
        if !a["#{@sort_query[1]}"].is_a?(Integer)
          a["#{@sort_query[1]}"].downcase
        else
          a["#{@sort_query[1]}"]
        end
      }
    elsif @sort_query[0] == 'DESC'
      @table_data_array_with_hashes = @table_data_array_with_hashes.sort_by{|a|
        if !a["#{@sort_query[1]}"].is_a?(Integer)
          a["#{@sort_query[1]}"].downcase
        else
          a["#{@sort_query[1]}"]
        end
      }.reverse

    end
  end

  # select
  def filter_table_by_select_req()
    filtered_set = []
    @table_data_array_with_hashes.each do |row|
      filtered_hash = {}
      @select_request.each do |column|
        filtered_hash["#{column}"] = row["#{column}"]
      end
      filtered_set.push(filtered_hash)
    end
    @table_data_array_with_hashes = filtered_set
  end
end