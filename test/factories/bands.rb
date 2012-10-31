FactoryGirl.define do
  factory :metallica, :class => Band do |b|
    b.name 'Metallica'
  end

  factory :oasis, :class => Band do |b|
    b.name 'Oasis'
  end
end