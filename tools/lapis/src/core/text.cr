module Lapis
  module Core
    module Text
      # Calculates the Levenshtein edit distance between two strings
      def self.levenshtein_distance(str1 : String, str2 : String) : Int32
        s1, s2 = str1.chars, str2.chars
        m, n = s1.size, s2.size
        d = Array.new(m + 1) { Array.new(n + 1, 0) }

        (0..m).each { |i| d[i][0] = i }
        (0..n).each { |j| d[0][j] = j }

        (1..m).each do |i|
          (1..n).each do |j|
            cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1
            d[i][j] = Math.min(
              d[i - 1][j] + 1,          # deletion
              Math.min(
                d[i][j - 1] + 1,        # insertion
                d[i - 1][j - 1] + cost  # substitution
              )
            )
          end
        end
        d[m][n]
      end

      # Suggests the closest matching candidate from a collection, or nil if none within max_distance
      def self.suggest(typo : String, candidates : Enumerable(String), max_distance : Int32 = 3) : String?
        best = candidates.min_by? { |c| levenshtein_distance(typo.downcase, c) }
        if best && levenshtein_distance(typo.downcase, best) <= max_distance
          best
        else
          nil
        end
      end
    end
  end
end
