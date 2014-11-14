# encoding: utf-8

require 'spec_helper'

describe Tootsie::ImageUtils do

  subject do
    Tootsie::ImageUtils
  end

  describe '#compute_dimensions' do
    describe "method 'down'" do
      it 'scales dimensions down' do
        expect(
          subject.compute_dimensions(:down, 200, 100, 50, 50)
        ).to eq([50, 25])

        expect(
          subject.compute_dimensions(:down, 200, 200, 50, 50)
        ).to eq([50, 50])

        expect(
          subject.compute_dimensions(:down, 200, 300, 50, 50)
        ).to eq([33, 50])

        expect(
          subject.compute_dimensions(:down, 200, 300, 200, 100)
        ).to eq([67, 100])

        expect(
          subject.compute_dimensions(:down, 200, 300, 100, 200)
        ).to eq([100, 150])
      end
    end

    describe "method 'fit'" do
      it 'scales dimensions' do
        expect(
          subject.compute_dimensions(:fit, 200, 100, 50, 50)
        ).to eq([100, 50])

        expect(
          subject.compute_dimensions(:fit, 200, 200, 50, 50)
        ).to eq([50, 50])

        expect(
          subject.compute_dimensions(:fit, 200, 300, 50, 50)
        ).to eq([50, 75])

        expect(
          subject.compute_dimensions(:fit, 200, 300, 200, 100)
        ).to eq([200, 300])

        expect(
          subject.compute_dimensions(:fit, 200, 300, 100, 200)
        ).to eq([134, 200])
      end
    end

    describe "method 'up'" do
      it 'scales dimensions' do
      end
    end
  end

end