namespace :jit do
  task :generate_header do
    puts "GEN vm/llvm/types.cpp.gen"

    classes = %w!rubinius::ObjectHeader
                 rubinius::Object
                 rubinius::CallFrame
                 rubinius::UnwindInfo
                 rubinius::VariableScope
                 rubinius::CompiledMethod
                 rubinius::Executable
                 rubinius::Dispatch
                 rubinius::Arguments
                 rubinius::Tuple
                 rubinius::Array
                 rubinius::Class
                 rubinius::Module
                 rubinius::StaticScope
                 rubinius::InstructionSequence
                 rubinius::InlineCache
                 rubinius::BlockEnvironment
                 rubinius::BlockInvocation
                 jit_state!
    require 'tempfile'

    files = %w!vm/call_frame.hpp
               vm/arguments.hpp
               vm/dispatch.hpp
               vm/inline_cache.hpp
               vm/builtin/block_environment.hpp!
    path = "llvm-type-temp.cpp"

    File.open(path, "w+") do |f|
      files.each do |file|
        f.puts "#include \"#{file}\""
      end

      i = 0
      classes.each do |klass|
        f.puts "void useme#{i}(#{klass}* thing);"
        f.puts "void blah#{i}(#{klass}* thing) { useme#{i}(thing); }"
        i += 1
      end
    end

    str = `llvm-g++ -I. -Ivm -Ivm/external_libs/libtommath -emit-llvm -S -o - "#{path}"`

    File.unlink path

    types = []

    str.split("\n").each do |line|
      classes.each do |klass|
        if /%"?struct.#{klass}(::\$[^\s]+)?"? = type/.match(line)
          types << line
        end
      end
    end

    opaque = %w!VM TypeInfo VMMethod Fixnum Symbol Selector LookupTable!

    File.open("vm/gen/types.ll","w+") do |f|
      opaque.each do |o|
        f.puts "%\"struct.rubinius::#{o}\" = type opaque"
      end
      f.puts(*types)
    end

    `llvm-as < vm/gen/types.ll > vm/gen/types.bc`
    `llc -march=cpp -cppgen=contents -f -o vm/llvm/types.cpp.gen vm/gen/types.bc`
  end
end
