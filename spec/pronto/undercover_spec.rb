# frozen_string_literal: true

RSpec.describe Pronto::Undercover do
  it 'has a version number' do
    expect(Pronto::UndercoverVersion::VERSION).not_to be nil
  end

  describe '#run' do
    let(:patches) { [] } # pronto-undercover uses own git wrapper for now
    subject { Pronto::Undercover.new(patches) }

    it 'returns no messages by default' do
      expect(subject.run).to be_empty
    end

    context 'with changes' do
      let(:test_repo_path) { File.expand_path('../fixtures', __dir__) }

      # pronto-undercover only runs in current workdir for now
      before { Dir.chdir(test_repo_path) }
      after { Dir.chdir(__dir__) }

      it 'reports undercover warnings as messages with' do
        results = Pronto.run(:staged, 'test.git', nil)

        expect(results.size).to eq(2)
      end

      it 'reports severity, text, filename and line number' do
        results = Pronto.run(:staged, 'test.git', nil)

        msg = results.first
        expect(msg).to be_a(Pronto::Message)
        expect(msg.line).to be_a(Pronto::Git::Line)
        expect(msg.msg).to eq(
          # TODO: make this output better
          'instance method foo needs a test! (coverage: 0.0)'
        )
        expect(msg.level).to eq(:warning)
        expect(msg.line.new_lineno).to eq(8)
      end

      it 'passes options from .pronto.yml to Undercover::Report' do
        config = {
          'lcov' => 'coverage/lcov/fixtures.lcov',
          'path' => '.',
          'ruby-syntax' => 'ruby22'
        }
        File.open('.pronto.yml', 'w') do |config_file|
          config_file.write(config.to_yaml)
        end

        expect(Undercover::Report)
          .to receive(:new).and_wrap_original do |m, changeset, opts|
          expect(opts.lcov).to eq('coverage/lcov/fixtures.lcov')
          expect(opts.path).to eq('.')
          expect(opts.syntax_version).to eq('ruby22')
          m.call(changeset, opts)
        end

        Pronto.run(:staged, 'test.git', nil)

        FileUtils.rm('.pronto.yml')
      end

      it 'prints a warning message with no available lcov file' do
        File.open('.pronto.yml', 'w') do |config_file|
          config_file.write({'lcov' => 'does_not_exist'}.to_yaml)
        end

        errmsg = 'Could not open file! No such file or' \
                 " directory @ rb_sysopen - does_not_exist\n"
        expect { Pronto.run(:staged, 'test.git', nil) }
          .to output(errmsg).to_stderr

        FileUtils.rm('.pronto.yml')
      end
    end
  end
end
