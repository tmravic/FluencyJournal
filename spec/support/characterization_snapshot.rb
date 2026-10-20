# Records observed behaviour as JSON and compares later runs against it.
#
# Characterization specs use it to pin what the app does today before a
# refactor, so the refactor can prove it changed nothing. Regenerate after
# an intended change with UPDATE_CHARACTERIZATION=1.
#
#   SNAPSHOT = CharacterizationSnapshot.new("followups")
#   SNAPSHOT.match(self, "new/entry", observation)   # inside an example
class CharacterizationSnapshot
  def self.updating?
    ENV["UPDATE_CHARACTERIZATION"].present?
  end

  def initialize(name)
    @path = Rails.root.join("spec/fixtures/files/characterization/#{name}.json")
    @stored = @path.exist? ? JSON.parse(@path.read) : {}
    @recorded = {}
    at_exit { write } if self.class.updating?
  end

  def match(example, key, observation)
    value = JSON.parse(JSON.generate(observation))
    @recorded[key] = value
    return if self.class.updating?

    example.expect(@stored).to example.have_key(key), "no snapshot #{key}; run with UPDATE_CHARACTERIZATION=1"
    example.expect(value).to example.eq(@stored[key]), "behaviour changed: #{key}"
  end

  private

  def write
    FileUtils.mkdir_p(@path.dirname)
    File.write(@path, JSON.pretty_generate(@stored.merge(@recorded).sort.to_h) + "\n")
  end
end
