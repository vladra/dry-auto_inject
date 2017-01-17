require 'dry/auto_inject/strategies/constructor'

module Dry
  module AutoInject
    class Strategies
      # @api private
      class Kwargs < Constructor
        private

        def define_new
          class_mod.class_exec(container, dependency_map) do |container, dependency_map|
            define_method :new do |*args, **kwargs|
              deps = dependency_map.to_h.each_with_object({}) { |(name, identifier), obj|
                obj[name] = kwargs[name] || container[identifier]
              }.merge(kwargs)

              super(*args, **deps)
            end
          end
        end

        def define_initialize(klass)
          super_method = Dry::AutoInject.super_method(klass, :initialize)

          if super_method.nil? || super_method.parameters.empty?
            define_initialize_with_keywords
          else
            define_initialize_with_splat(super_method)
          end

          self
        end

        def define_initialize_with_keywords
          initialize_params = dependency_map.names.map { |name| "#{name}: nil" }.join(', ')

          instance_mod.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def initialize(#{initialize_params})
              super()
              #{dependency_map.names.map { |name| "@#{name} = #{name}" }.join("\n")}
            end
          RUBY
          self
        end

        def define_initialize_with_splat(super_method)
          super_kwarg_names = super_method.parameters.select { |type, _| [:key, :keyreq].include?(type) }.map(&:last)
          super_kw_params = super_kwarg_names.map { |name| "#{name}: kwargs[:#{name}]" }.join(', ')

          # Pass through any non-dependency args if the super method accepts `**args`
          if super_method.parameters.any? { |type, _| type == :keyrest }
            if super_kw_params.empty?
              super_kw_params = '**kwargs'
            else
              super_kw_params += ', **kwargs'
            end
          end

          instance_mod.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def initialize(*args, **kwargs)
              super(*args, #{super_kw_params})
              #{dependency_map.names.map { |name| "@#{name} = kwargs[:#{name}]" }.join("\n")}
            end
          RUBY
          self
        end
      end

      register_default :kwargs, Kwargs
    end
  end
end
