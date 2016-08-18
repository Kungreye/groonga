#!/usr/bin/env ruby

require "fileutils"
require "json"

def check_max_index(options)
  max_n_segments = options[:max_n_segments]
  max_n_chunks = options[:max_n_chunks]
  n_patterns = options[:n_patterns] || 2

  ENV["GRN_II_MAX_N_SEGMENTS_TINY"] = max_n_segments&.to_s
  ENV["GRN_II_MAX_N_CHUNKS_TINY"] = max_n_chunks&.to_s

  db_dir = "/dev/shm/db"
  log_path = "#{db_dir}/log"
  FileUtils.rm_rf(db_dir)
  FileUtils.mkdir_p(db_dir)
  command_line = [
    "groonga",
    "--log-path", log_path,
    "-n", "#{db_dir}/db",
  ]
  IO.popen(command_line, "r+") do |groonga|
    groonga.puts("table_create x TABLE_HASH_KEY UInt32")
    groonga.gets
    groonga.puts("column_create x y COLUMN_SCALAR UInt32")
    groonga.gets
    groonga.puts("table_create a TABLE_PAT_KEY UInt32")
    groonga.gets
    groonga.puts("column_create a b COLUMN_INDEX|INDEX_TINY x y")
    groonga.gets

    groonga.puts("load --table x")
    groonga.puts("[")
    File.open(log_path) do |log|
      log.seek(0, IO::SEEK_END)
      log_size = log.size
      i = 0
      catch do |abort|
        loop do
          y = i + 1
          n_patterns.times do
            groonga.print(JSON.generate({"_key" => i, "y" => y}))
            groonga.puts(",")
            groonga.flush
            i += 1
            if log.size != log_size
              data = log.read
              if /\|[Ae]\|/ =~ data
                parameters = [
                  max_n_segments.inspect,
                  max_n_chunks.inspect,
                  n_patterns.inspect,
                  i,
                ]
                puts(parameters.join("\t"))
                # puts data
                throw(abort)
              end
              log_size = log.size
            end
          end
        end
      end
    end
    groonga.puts("]")
    groonga.gets

    groonga.puts("quit")
    groonga.gets
  end
end

puts("N segments\tN chunks\tN patterns\tN records")
[
  [1, 1, 2],
  [2, 2, 2],
  [4, 4, 2],
  [8, 8, 2],
  [16, 16, 2],
  [32, 32, 2],
  [64, 64, 2],
  [128, 128, 2],
  [256, 256, 2],
  [nil, nil, 1],
  [nil, nil, 2],
  [nil, nil, 4],
  [nil, nil, 8],
  [nil, nil, 16],
  [nil, nil, 32],
  [nil, nil, 64],
  [nil, nil, 128],
  [nil, nil, 256],
].each do |max_n_segments, max_n_chunks, n_parameters|
  check_max_index(:max_n_segments => max_n_segments,
                  :max_n_chunks => max_n_chunks,
                  :n_patterns => n_parameters)
end
