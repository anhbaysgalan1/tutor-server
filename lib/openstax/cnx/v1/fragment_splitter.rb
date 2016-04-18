module OpenStax::Cnx::V1
  class FragmentSplitter

    include HtmlTreeOperations

    attr_reader :processing_instructions

    def initialize(processing_instructions)
      @processing_instructions = processing_instructions.map{ |pi| OpenStruct.new(pi.to_h) }
    end

    # Splits the given root node into fragments according to the processing instructions
    def split_into_fragments(root, type = nil)
      result = [root.dup]
      type_string = type.to_s

      processing_instructions.each do |processing_instruction|
        next if processing_instruction.css.blank? ||
                processing_instruction.fragments.nil? ||
                (!processing_instruction.only.nil? &&
                 ![processing_instruction.only].flatten.map(&:to_s).include?(type_string)) ||
                (!processing_instruction.except.nil? &&
                 [processing_instruction.except].flatten.map(&:to_s).include?(type_string))

        result = process_array(result, processing_instruction)
      end

      cleanup_array(result)
    end

    protected

    class CustomCss
      define_method(:'has-descendants') do |node_set, selector, number = 1|
        node_set.select{ |node| node.css(selector).size >= number }
      end
    end

    def custom_css
      @custom_css ||= CustomCss.new
    end

    # Gets the fragments for a Nokogiri::XML::Node according to a ProcessingInstruction
    def get_fragments(node, root, processing_instruction)
      [processing_instruction.fragments].flatten.map do |fragment_name|
        fragment_class_name = fragment_name.to_s.classify
        if fragment_class_name == "Node"
          # Make a copy of the current node (up to the root), but remove all other nodes
          root_copy = root.dup
          node_copy = root_copy.at_css(processing_instruction.css, custom_css)

          remove_before(node_copy, root_copy)
          remove_after(node_copy, root_copy)

          next root_copy
        end

        fragment_class = "OpenStax::Cnx::V1::Fragment::#{fragment_class_name}".constantize
        fragment = fragment_class.new(node: node, labels: processing_instruction.labels)
        fragment unless fragment.blank?
      end.compact
    end

    # Process a single Nokogiri::XML::Node
    def process_node(root, processing_instruction)
      # Find first match
      node = root.at_css(processing_instruction.css, custom_css)

      # Base case
      return root if node.nil?

      # Get fragments for the match
      fragments = get_fragments(node, root, processing_instruction)

      if fragments.empty? # No splitting needed
        # Remove the match node and any empty parents from the tree
        recursive_compact(node, root)

        # Repeat the processing until no more matches
        process_node(root, processing_instruction)
      else # Need to split the node tree
        # Copy the node content and find the same match in the copy
        root_copy = root.dup
        node_copy = root_copy.at_css(processing_instruction.css, custom_css)

        # One copy retains the content before the match;
        # the other retains the content after the match
        remove_after(node, root)
        remove_before(node_copy, root_copy)

        # Remove the match, its copy and any empty parents from the 2 trees
        recursive_compact(node, root)
        recursive_compact(node_copy, root_copy)

        # Repeat the processing until no more matches
        [root, fragments, process_node(root_copy, processing_instruction)]
      end
    end

    # Recursively process an array of Nodes and Fragments
    def process_array(array, processing_instruction)
      array.map do |obj|
        case obj
        when Array
          process_array(obj, processing_instruction)
        when Nokogiri::XML::Node
          process_node(obj, processing_instruction)
        else
          obj
        end
      end
    end

    # Flatten, remove empty nodes and transform remaining nodes into reading fragments
    def cleanup_array(array)
      array.flatten.map do |obj|
        next obj unless obj.is_a?(Nokogiri::XML::Node)
        next if obj.content.blank?

        OpenStax::Cnx::V1::Fragment::Reading.new(node: obj)
      end.compact
    end

  end
end
