module Prismic
  module JsonParser
    class << self
      def parsers
        @parsers ||= {
          'Link.document'  => method(:document_link_parser),
          'Text'           => method(:text_parser),
          'Link.web'       => method(:web_link_parser),
          'Date'           => method(:date_parser),
          'Number'         => method(:number_parser),
          'Embed'          => method(:embed_parser),
          'Image'          => method(:image_parser),
          'Color'          => method(:color_parser),
          'StructuredText' => method(:structured_text_parser),
          'Select'         => method(:select_parser),
          'Multiple'       => method(:multiple_parser),
        }
      end

      def document_link_parser(json)
        Prismic::Fragments::DocumentLink.new(
          json['value']['document']['id'],
          json['value']['document']['type'],
          json['value']['document']['tags'],
          json['value']['document']['slug'],
          json['value']['isBroken'])
      end

      def text_parser(json)
        Prismic::Fragments::Text.new(json['value'])
      end

      def select_parser(json)
        Prismic::Fragments::Text.new(json['value'])
      end

      def web_link_parser(json)
        Prismic::Fragments::WebLink.new(json['value']['url'])
      end

      def date_parser(json)
      end

      def number_parser(json)
        Prismic::Fragments::Number.new(json['value'])
      end

      def embed_parser(json)
      end

      def image_parser(json)
        def self.view_parser(json)
          Prismic::Fragments::Image::View.new(json['url'],
                                              json['dimensions']['width'],
                                              json['dimensions']['height'])
        end

        main  = view_parser(json['value']['main'])
        views = json['value']['views'].map do |name, view|
          view_parser(view)
        end

        Prismic::Fragments::Image.new(main, views)
      end

      def color_parser(json)
        Prismic::Fragments::Color.new(json['value'][1..6])
      end

      def structured_text_parser(json)
        def self.span_parser(span)
          if span['type'] == 'em'
            Prismic::Fragments::StructuredText::Span::Em.new(span['start'], span['end'])
          elsif span['type'] == 'strong'
            Prismic::Fragments::StructuredText::Span::Strong.new(span['start'], span['end'])
          elsif span['type'] == 'hyperlink'
            Prismic::Fragments::StructuredText::Span::Hyperlink.new(span['start'], span['end'], link_parser(span['data']))
          end
        end

        blocks = json['value'].map do |block|
          if block['type'] == 'paragraph'
            spans = block['spans'].map {|span| span_parser(span)}
            Prismic::Fragments::StructuredText::Block::Paragraph.new(block['text'], spans)
          elsif block['type'] =~ /^heading/
            spans = block['spans'].map {|span| span_parser(span)}
            Prismic::Fragments::StructuredText::Block::Heading.new(block['text'],
                                                                  spans,
                                                                  block['type'][-1].to_i)
          end
        end
        Prismic::Fragments::StructuredText.new(blocks)
      end

      def multiple_parser(json)
        foo = json.map do |fragment|
          parsers[fragment['type']].call(fragment)
        end
        Prismic::Fragments::Multiple.new(foo)
      end

      def document_parser(json)
        fragments = Hash[json['data'].values.first.map do |name, fragment|
          if fragment.is_a? Array
            [name, multiple_parser(fragment)]
          else
            [name, parsers[fragment['type']].call(fragment)]
          end
        end]

        Prismic::Document.new(json['id'], json['type'], json['href'], json['tags'],
                              json['slugs'], fragments)
      end

      private

      private

      def link_parser(json)
        if json['type'] == 'Link.document'
          document_link_parser(json)
        elsif json['type'] == 'Link.web'
          web_link_parser(json)
        end
      end
    end
  end
end
