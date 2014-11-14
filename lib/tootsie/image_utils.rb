module Tootsie
  module ImageUtils

    def self.compute_dimensions(method,
      original_width, original_height,
      target_width, target_height)
      aspect = original_height / original_width.to_f
      case method
        when :up
          if original_width < target_width or original_height < target_height
            if original_width > original_height
              w = target_width
              h = (w / aspect).round
            else
              w = (target_height / aspect).round
              h = target_height
            end
          else
            return compute_dimensions(:fit,
              original_width, original_height,
              target_width, target_height)
          end
        when :down
          if original_height > target_height
            if target_height / aspect > target_width
              w = [original_width, target_width].min.round
              h = (w * aspect).round
            else
              h = target_height
              w = (h / aspect).round
            end
          elsif original_width > target_width
            if target_width * aspect > target_height
              h = [original_height, target_height].min.round
              w = (h / aspect).round
            else
              w = target_width
              h = (w * aspect).round
            end
          end
        when :fit
          if (target_width * aspect).ceil < target_height
            h = target_height
            w = (target_height / aspect).ceil
          elsif (target_height / aspect).ceil < target_width
            w = target_width
            h = (target_width * aspect).ceil
          end
        else
          raise ArgumentError, "Invalid scaling method"
      end
      w ||= target_width
      h ||= target_height
      [w, h]
    end

  end
end
