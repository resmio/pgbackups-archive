require "test_helper"
require "heroku/client"

describe Heroku::Client::PgbackupsArchive do

  describe "#self.perform" do
    before do
      Heroku::Client::PgbackupsArchive.expects(:new).returns(
        mock(
          :capture  => stub,
          :download => stub,
          :archive  => stub,
          :delete   => stub
        )
      )
    end

    it { Heroku::Client::PgbackupsArchive.perform }
  end

  describe "An instance" do
    let(:database_url)  { "db_url" }
    let(:pgbackups_url) { "https://ip:password@pgbackups.heroku.com/client" }
    let(:backup)        { Heroku::Client::PgbackupsArchive.new }

    before do
      ENV["PGBACKUPS_URL"] = pgbackups_url
    end

    describe "#initialize" do
      it "should set client to a Heroku::Client::Pgbackups instance" do
        backup.client.class.must_equal Heroku::Client::Pgbackups
      end
    end

    describe "#archive" do
      let(:key)  { "some-key" }
      let(:file) { "some-file" }

      before do
        backup.stubs(:key).returns(key)
        backup.stubs(:file).returns(file)

        PgbackupsArchive::Storage.expects(:new).with(key, file)
          .returns(mock(:store => stub))
      end

      it "should use a storage instance to store the archive" do
        backup.archive
      end
    end

    describe "#capture" do
      let(:pgbackup) { { "finished_at" => "some-timestamp" } }

      before do
        backup.stubs(:database_url).returns(database_url)

        backup.client.expects(:create_transfer)
          .with(database_url, database_url, nil, "BACKUP", :expire => true)
          .returns(pgbackup)
      end

      it "uses the client to create a pgbackup" do
        backup.capture
      end
    end

    describe "#delete" do
      let(:temp_file) { "temp-file" }

      before do
        backup.stubs(:temp_file).returns(temp_file)
        File.expects(:delete).with(temp_file).returns(true)
      end

      it "should delete the temp file" do
        backup.delete
      end
    end

    describe "#download" do
      let(:pgbackup) do
        {
          "public_url" => "https://raw.github.com/kjohnston/" +
            "pgbackups-archive/master/pgbackups-archive.gemspec"
        }
      end

      before do
        backup.instance_eval do
          @pgbackup = {
            "public_url" => "https://raw.githubusercontent.com/kjohnston/pgbackups-archive/master/pgbackups-archive.gemspec"
          }
        end
        backup.download
      end

      it "downloads the backup file" do
        backup.send(:file).read.must_match /Gem::Specification/
      end

      after do
        backup.delete
      end
    end

    describe "#database_url" do
      describe "when an alternate database to backup is not set" do
        before do
          ENV["PGBACKUPS_DATABASE_URL"] = nil
          ENV["DATABASE_URL"] = "default_url"
        end

        it "defaults to using the DATABASE_URL" do
          backup.send(:database_url).must_equal "default_url"
        end
      end

      describe "an alternate database to backup is set" do
        before do
          ENV["PGBACKUPS_DATABASE_URL"] = "alternate_url"
          ENV["DATABASE_URL"] = "default_url"
        end

        it "uses the PGBACKUPS_DATABASE_URL" do
          backup.send(:database_url).must_equal "alternate_url"
        end
      end
    end

    describe "#file" do
      let(:temp_file) { "temp-file" }

      before do
        backup.stubs(:temp_file).returns(temp_file)
        File.expects(:open).with(temp_file, "r").returns("")
      end

      it { backup.send(:file) }
    end

    describe "#key" do
      before do
        backup.instance_eval do
          @pgbackup = {
            "finished_at" => "timestamp"
          }
        end
      end

      it "should be composed properly" do
        path = ["pgbackups", backup.send(:environment), "timestamp.dump"]
          .compact.join("/")
        backup.send(:key).must_equal path
      end
    end

    describe "#pgbackups_url" do
      it { backup.send(:pgbackups_url).must_equal pgbackups_url }
    end

    describe "#temp_file" do
      before do
        backup.instance_eval do
          @pgbackup = {
            "public_url" => "https://raw.github.com/kjohnston/pgbackups-archive/master/pgbackups-archive.gemspec"
          }
        end
      end

      it "should be composed properly" do
        temp_file = backup.send(:temp_file)
        temp_file.must_match /^\/var\//
        temp_file.must_match /\/pgbackups-archive.gemspec$/
      end
    end

  end

end
