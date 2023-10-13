# frozen_string_literal: true

require "rails/generators/resource_helpers"

module Rails
  module Generators
    class ScaffoldControllerGenerator < NamedBase # :nodoc:
      include ResourceHelpers

      check_class_collision suffix: "Controller"

      class_option :helper, type: :boolean
      class_option :orm, banner: "NAME", type: :string, required: true,
                         desc: "ORM to generate the controller for"
      class_option :api, type: :boolean,
                         desc: "Generates API controller"

      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      def create_controller_files
        template_file = options.api? ? "api_controller.rb" : "controller.rb"
        template template_file, File.join("app/controllers", controller_class_path, "#{controller_file_name}_controller.rb")
      end

      hook_for :template_engine, as: :scaffold do |template_engine|
        invoke template_engine unless options.api?
      end

      hook_for :test_framework, as: :scaffold

      # Invoke the helper using the controller name (pluralized)
      hook_for :helper, as: :scaffold do |invoked|
        invoke invoked, [ controller_name ]
      end

      private

        def permitted_params
          params = attributes_names.map { |name| ":#{name}" }.join(", ")
          params += attributes.select(&:attachments?).map { |a| ", #{a.name}: []" }.join
          params
        end
    end
  end
end
