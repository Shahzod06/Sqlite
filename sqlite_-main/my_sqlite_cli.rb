class SQLiteParser
    attr_accessor :valid_query_methods
  
    def initialize
      require 'readline'
      require 'csv'
      require './my_sqlite_request'
      @valid_query_methods_params = [:SELECT, :FROM, :INSERT, :UPDATE, :VALUES, :SET, :JOIN, :WHERE, :ORDER, :DELETE, :ASC, :DESC, :AND]
      @valid_query_methods = @valid_query_methods_params
  
    end
  
    def parse_args_from_input(query)
      arg_values_p1 = []
      arg_values = arg_values_p1
      @user_input.each_index do |i|
        if @user_input[i].to_sym == query
          i += 1
          @user_input[i..-1].each do |input|
            input = input.to_sym
            break if @valid_query_methods.include?(input) || !input
            if input == :INTO || input == :into
              next
            elsif input == :ON
              next
            elsif query == :JOIN && input == '='.to_sym
              next
            end
  
            args = input.to_s
            arg_values.push(args)
          end
        end
  
      end
      return arg_values
    end
  
  
    def split_args(string)
      delimiters_p1 = ['"', "'"]
      delimiters = delimiters_p1
      split_str_sqli = string.split(Regexp.union(delimiters))
      split_str = split_str_sqli
      split_outside_quotes = split_str.each_with_index.map do |element, i|
        if i.even?
          element.split(' ')
        end
      end.compact
  
      split_outside_quotes.each do |array|
        array.each do |element|
  
          element.delete!(',()') if element.include?(',()')
          element.delete!('()') if element.include?('()')
          element.delete!(',') if element.include?(',')
          element.delete!('(') if element.include?('(')
          element.delete!(')') if element.include?(')')
          element.delete!(';') if element.include?(';')
          array.delete(element) if element == ''
  
          element.to_i if element.match?(/\A\d+\z/)
        end
      end
  
      split_str.each_with_index do |element, i|
        split_str[i] = split_outside_quotes[i / 2] if i.even?
      end
  
      split_str.flatten
    end

  
    def create_hash_from_insert_args_join(string)
      columns_pi = []
      columns = columns_pi
      result_hash_pon = {}
      result_hash = result_hash_pon
  
      if string.count('(') > 1
        insert_column_values = string[string.index('(')+1..string.index(')')-1];
        string.slice!(string.index('(')..string.index(')'))
        columns = insert_column_values.split(',').map(&:strip)
  
      else
        file_name = ''
        split_str = string.split(' ')
        split_str.each do |element|
  
          if element.include?('.csv')
            file_name = element
          end
  
        end
        columns = CSV.open(file_name, 'r') { |csv| csv.first }
        columns.each do |column|
          if column == 'id'
            columns.delete(column)
          end
        end
      end
  
      insert_values_b2 = string[string.index('(')+1..string.index(')')-1].split(',').map(&:strip)
      insert_values = insert_values_b2
      string.slice!(string.index('(')..-1)
  
      insert_values.each_with_index do |value, i|
        insert_values[i] = value.delete_prefix("'").delete_suffix("'")
      end
  
      columns.each_with_index do |value, i|
        result_hash["#{value}"] = insert_values[i]
      end
  
      return result_hash
    end
  
    def create_hash_from_set_args_oop(string)
      result_hash_ki = {}
      result_hash =result_hash_ki
      set_index_li = string.index('SET')
      set_index =set_index_li
      set_values_pon = ''
      set_values = set_values_pon
  
      if string.split(' ').include?('WHERE')
        where_index_jin = string.index('WHERE')
        where_index = where_index_jin
        set_values_bi_2 = string[set_index+4..where_index-1].split(',').map(&:strip)
        set_values = set_values_bi_2
        string.slice!(set_index..where_index-1)
      else
        set_values = string[set_index+4..-1].split(',').map(&:strip)

        string.slice!(set_index..-1)
      end
  
      set_values.each_index do |i|
        delimiters_kill = ['"', "'"]
        delimiters = delimiters_kill
        set_values[i]  = set_values[i].split(Regexp.union(delimiters))
        split_set_values_pk = set_values[i][0].split(' ')
        split_set_values = split_set_values_pk
        result_hash["#{split_set_values[0]}"] = set_values[i][1]
      end
  
      return result_hash
    end
  
    def parse_input_res(args)
  
      if args.split(' ').include?('INSERT')
        @values_hash = create_hash_from_insert_args_join(args)
        @request = @request.values(@values_hash)
      end
  
      if args.split(' ').include?('UPDATE')
        @values_hash = create_hash_from_set_args_oop(args)
        @request = @request.set(@values_hash)
      end
  
      @user_input = split_args(args)
      i = 0
  
      @user_input.each do |query|
        case query.to_sym
        when :SELECT
          select_request = parse_args_from_input(:SELECT)
          @request = @request.select(select_request)
        when :INSERT
          insert_request = parse_args_from_input(:INSERT)
          @request = @request.insert(insert_request[0])
        when :UPDATE
          update_request = parse_args_from_input(:UPDATE)
          @request = @request.update(update_request[0])
        when :DELETE
          delete_request = parse_args_from_input(:DELETE)
          @request = @request.delete
        when :FROM
          from_request = parse_args_from_input(:FROM)
          @request = @request.from(from_request[0])
        when :WHERE
          where_request = parse_args_from_input(:WHERE)
          @request = @request.where(where_request[0], where_request[2])
          @request = @request.where_comparison_operator(where_request[1], 0)
        when :JOIN
          join_request = parse_args_from_input(:JOIN)
          @request = @request.join(join_request[1], join_request[0], join_request[2])
        when :ORDER
          order_request = parse_args_from_input(:ORDER)
          @request = @request.order(order_request[1])
        when :DESC
          @request = @request.desc_order()
        when :AND
          i += 1;
          second_where_request = parse_args_from_input(:AND)
          @request = @request.where(second_where_request[0], second_where_request[2])
          @request = @request.where_comparison_operator(second_where_request[1], i)
        end
      end
      return @request.run
    end
  
    def run()
      puts "MySQLite version 1.0 2022-12-20"
      loop do
        user_args = Readline.readline("my_sqlite_cli>> ", true)
        if user_args == 'exit'
          break
        end
        @request = MySqliteRequest.new
        @request = @request.args_from_cli
        parse_input_res(user_args)
      end
    end
  end
  
  
  
  def main()
    cli = SQLiteParser.new
    cli.run()
  end
  
  main()
  