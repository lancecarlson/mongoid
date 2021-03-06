# encoding: utf-8
module Mongoid #:nodoc:
  module Dirty #:nodoc:
    extend ActiveSupport::Concern
    module InstanceMethods #:nodoc:
      # Gets the changes for a specific field.
      #
      # Example:
      #
      #   person = Person.new(:title => "Sir")
      #   person.title = "Madam"
      #   person.attribute_change("title") # [ "Sir", "Madam" ]
      #
      # Returns:
      #
      # An +Array+ containing the old and new values.
      def attribute_change(name)
        modifications[name]
      end

      # Determines if a specific field has chaged.
      #
      # Example:
      #
      #   person = Person.new(:title => "Sir")
      #   person.title = "Madam"
      #   person.attribute_changed?("title") # true
      #
      # Returns:
      #
      # +true+ if changed, +false+ if not.
      def attribute_changed?(name)
        modifications.include?(name)
      end

      # Gets the old value for a specific field.
      #
      # Example:
      #
      #   person = Person.new(:title => "Sir")
      #   person.title = "Madam"
      #   person.attribute_was("title") # "Sir"
      #
      # Returns:
      #
      # The old field value.
      def attribute_was(name)
        change = modifications[name]
        change ? change[0] : nil
      end

      # Gets the names of all the fields that have changed in the document.
      #
      # Example:
      #
      #   person = Person.new(:title => "Sir")
      #   person.title = "Madam"
      #   person.changed # returns [ "title" ]
      #
      # Returns:
      #
      # An +Array+ of changed field names.
      def changed
        modifications.keys
      end

      # Alerts to whether the document has been modified or not.
      #
      # Example:
      #
      #   person = Person.new(:title => "Sir")
      #   person.title = "Madam"
      #   person.changed? # returns true
      #
      # Returns:
      #
      # +true+ if changed, +false+ if not.
      def changed?
        !modifications.empty?
      end

      # Gets all the modifications that have happened to the object as a +Hash+
      # with the keys being the names of the fields, and the values being an
      # +Array+ with the old value and new value.
      #
      # Example:
      #
      #   person = Person.new(:title => "Sir")
      #   person.title = "Madam"
      #   person.changes # returns { "title" => [ "Sir", "Madam" ] }
      #
      # Returns:
      #
      # A +Hash+ of changes.
      def changes
        modifications
      end

      # Call this method after save, so the changes can be properly switched.
      #
      # Example:
      #
      # <tt>person.move_changes</tt>
      def move_changes
        @previous_modifications = modifications.dup
        @modifications = {}
      end

      # Gets all the new values for each of the changed fields, to be passed to
      # a MongoDB $set modifier.
      #
      # Example:
      #
      #   person = Person.new(:title => "Sir")
      #   person.title = "Madam"
      #   person.setters # returns { "title" => "Madam" }
      #
      # Returns:
      #
      # A +Hash+ of new values.
      def setters
        modifications.inject({}) do |sets, (field, changes)|
          key = embedded? ? "#{_position}.#{field}" : field
          sets[key] = changes[1]; sets
        end
      end

      # Gets all the modifications that have happened to the object before the
      # object was saved.
      #
      # Example:
      #
      #   person = Person.new(:title => "Sir")
      #   person.title = "Madam"
      #   person.save!
      #   person.previous_changes # returns { "title" => [ "Sir", "Madam" ] }
      #
      # Returns:
      #
      # A +Hash+ of changes before save.
      def previous_changes
        @previous_modifications
      end

      # Resets a changed field back to its old value.
      #
      # Example:
      #
      #   person = Person.new(:title => "Sir")
      #   person.title = "Madam"
      #   person.reset_attribute!("title")
      #   person.title # "Sir"
      #
      # Returns:
      #
      # The old field value.
      def reset_attribute!(name)
        value = attribute_was(name)
        if value
          @attributes[name] = value
          modifications.delete(name)
        end
      end

      # Sets up the modifications hash. This occurs just after the document is
      # instantiated.
      #
      # Example:
      #
      # <tt>document.setup_notifications</tt>
      def setup_modifications
        @accessed ||= {}
        @modifications ||= {}
        @previous_modifications ||= {}
      end

      protected

      # Audit the original value for a field that can be modified in place.
      #
      # Example:
      #
      # <tt>person.accessed("aliases", [ "007" ])</tt>
      def accessed(name, value)
        @accessed[name] = value.dup if (value.is_a?(Array) || value.is_a?(Hash)) && !@accessed.has_key?(name)
        value
      end

      # Get all normal modifications plus in place potential changes.
      #
      # Example:
      #
      # <tt>person.modifications</tt>
      #
      # Returns:
      #
      # All changes to the document.
      def modifications
        @accessed.each_pair do |field, value|
          current = @attributes[field]
          @modifications[field] = [ value, current ] if current != value
        end
        @accessed.clear
        @modifications
      end

      # Audit the change of a field's value.
      #
      # Example:
      #
      # <tt>person.modify("name", "Jack", "John")</tt>
      def modify(name, old_value, new_value)
        @attributes[name] = new_value
        if @modifications && (old_value != new_value)
          original = @modifications[name].first if @modifications[name]
          @modifications[name] = [ (original || old_value), new_value ]
        end
      end
    end

    module ClassMethods #:nodoc:
      # Add the dynamic dirty methods. These are custom methods defined on a
      # field by field basis that wrap the dirty attribute methods.
      #
      # Example:
      #
      #   person = Person.new(:title => "Sir")
      #   person.title = "Madam"
      #   person.title_change # [ "Sir", "Madam" ]
      #   person.title_changed? # true
      #   person.title_was # "Sir"
      #   person.reset_title!
      def add_dirty_methods(name)
        define_method("#{name}_change") { attribute_change(name) }
        define_method("#{name}_changed?") { attribute_changed?(name) }
        define_method("#{name}_was") { attribute_was(name) }
        define_method("reset_#{name}!") { reset_attribute!(name) }
      end
    end
  end
end
