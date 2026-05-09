# db/seeds.rb

# Clear existing data to prevent duplication if re-seeding
Client.delete_all
SupportWorker.delete_all

clients = [
  {
    first_name: 'Elena', last_name: 'Martinez',
    location: 'Surry Hills, Sydney',
    phone: '0421 210 909',
    health_conditions: 'Hypertension',
    medication: 'Lisinopril', allergies: 'Ibuprofen',
    emergency_contact_name: 'Miguel Martinez', emergency_contact_phone: '0431 167 474'
  },
  {
    first_name: 'Raj', last_name: 'Patel',
    location: 'Fitzroy, Melbourne',
    phone: '0422 289 191',
    health_conditions: 'None',
    medication: 'None', allergies: 'Shellfish',
    emergency_contact_name: 'Anita Patel', emergency_contact_phone: '0423 324 141'
  },
  {
    first_name: 'Amina', last_name: 'Ali',
    location: 'Fortitude Valley, Brisbane',
    phone: '0424 986 262',
    health_conditions: 'Diabetes',
    medication: 'Metformin', allergies: 'Latex',
    emergency_contact_name: 'Yusuf Ali', emergency_contact_phone: '0425 542 929'
  },
  {
    first_name: 'Thomas', last_name: 'Rivera',
    location: 'Newtown, Sydney',
    phone: '0426 453 232',
    health_conditions: 'Asthma',
    medication: 'Ventolin', allergies: 'Penicillin',
    emergency_contact_name: 'Lucia Rivera', emergency_contact_phone: '0427 634 848'
  },
  {
    first_name: 'Mai', last_name: 'Nguyen',
    location: 'South Yarra, Melbourne',
    phone: '0428 748 282',
    health_conditions: 'Epilepsy',
    medication: 'Levetiracetam', allergies: 'Nuts',
    emergency_contact_name: 'Duy Nguyen', emergency_contact_phone: '0429 869 494'
  },
  {
    first_name: 'Sophie', last_name: 'Chen',
    location: 'Parramatta, Sydney',
    phone: '0430 112 345',
    health_conditions: 'Autism spectrum disorder',
    medication: 'None', allergies: 'None',
    emergency_contact_name: 'Wei Chen', emergency_contact_phone: '0431 223 456'
  },
  {
    first_name: 'James', last_name: 'O\'Brien',
    location: 'West End, Brisbane',
    phone: '0432 334 567',
    health_conditions: 'Dementia',
    medication: 'Donepezil', allergies: 'Aspirin',
    emergency_contact_name: 'Mary O\'Brien', emergency_contact_phone: '0433 445 678'
  },
]

clients.each { |c| Client.create!(c) }
puts "Clients seeded: #{Client.count}"

specializations = [
  'Child Care', 'Elderly Care', 'Disability Support', 'Mental Health Support',
  'Rehabilitation Support', 'Community Support', 'Physical Therapy', 'Healthcare Support'
]
specialization_objects = specializations.map { |name| Specialization.find_or_create_by(name: name) }

support_workers = [
  {
    first_name: 'Olivia', last_name: 'Williams',
    bio: 'Passionate about providing quality support to clients. Experienced in aged care and disability services.',
    experience: '7 years working with elderly and disabled clients in the Sydney metro area.',
    phone: '0400 123 456', email: 'olivia.williams@example.com',
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri], time_window: '08:00-18:00' }),
    location: 'Bondi, Sydney',
    specializations: specialization_objects.select { |s| ['Elderly Care', 'Disability Support'].include?(s.name) },
  },
  {
    first_name: 'James', last_name: 'Smith',
    bio: 'Experienced in mental health and rehabilitation support with a warm, person-centred approach.',
    experience: '5 years in community support across Melbourne.',
    phone: '0400 234 567', email: 'james.smith@example.com',
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri Sat Sun], time_window: '09:00-17:00' }),
    location: 'Richmond, Melbourne',
    specializations: specialization_objects.select { |s| ['Mental Health Support', 'Rehabilitation Support', 'Community Support'].include?(s.name) },
  },
  {
    first_name: 'Priya', last_name: 'Sharma',
    bio: 'Dedicated healthcare support worker with specialist training in physical therapy assistance.',
    experience: '4 years in disability and healthcare support in Brisbane.',
    phone: '0401 345 678', email: 'priya.sharma@example.com',
    availability: JSON.generate({ days: %w[Mon Wed Fri], time_window: '09:00-17:00' }),
    location: 'New Farm, Brisbane',
    specializations: specialization_objects.select { |s| ['Physical Therapy', 'Healthcare Support', 'Disability Support'].include?(s.name) },
  },
  {
    first_name: 'Liam', last_name: 'O\'Connor',
    bio: 'Compassionate support worker focused on community inclusion and independent living skills.',
    experience: '6 years supporting clients with intellectual disabilities in Perth.',
    phone: '0402 456 789', email: 'liam.oconnor@example.com',
    availability: JSON.generate({ days: %w[Tue Thu Sat Sun], time_window: '10:00-20:00' }),
    location: 'Fremantle, Perth',
    specializations: specialization_objects.select { |s| ['Community Support', 'Disability Support', 'Child Care'].include?(s.name) },
  },
  {
    first_name: 'Mei', last_name: 'Zhang',
    bio: 'Child and family support specialist with extensive experience in early intervention programs.',
    experience: '8 years in child care and family support services across Sydney.',
    phone: '0403 567 890', email: 'mei.zhang@example.com',
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri], time_window: '07:00-15:00' }),
    location: 'Chatswood, Sydney',
    specializations: specialization_objects.select { |s| ['Child Care', 'Community Support', 'Mental Health Support'].include?(s.name) },
  },
  {
    first_name: 'Daniel', last_name: 'Torres',
    bio: 'Rehabilitation specialist helping clients regain independence after injury or illness.',
    experience: '5 years in rehabilitation and healthcare support in Adelaide.',
    phone: '0404 678 901', email: 'daniel.torres@example.com',
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri Sat], time_window: '08:00-16:00' }),
    location: 'Norwood, Adelaide',
    specializations: specialization_objects.select { |s| ['Rehabilitation Support', 'Physical Therapy', 'Healthcare Support'].include?(s.name) },
  },
  {
    first_name: 'Aisha', last_name: 'Hassan',
    bio: 'Empathetic mental health support worker committed to trauma-informed, culturally safe practice.',
    experience: '3 years in mental health and community support in Melbourne.',
    phone: '0405 789 012', email: 'aisha.hassan@example.com',
    availability: JSON.generate({ days: %w[Sat Sun], time_window: '09:00-18:00' }),
    location: 'Brunswick, Melbourne',
    specializations: specialization_objects.select { |s| ['Mental Health Support', 'Community Support'].include?(s.name) },
  },
  {
    first_name: 'Nathan', last_name: 'Kowalski',
    bio: 'Versatile support worker experienced across aged care, disability, and community programs.',
    experience: '10 years in diverse support roles across the Gold Coast and Brisbane.',
    phone: '0406 890 123', email: 'nathan.kowalski@example.com',
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri], time_window: '12:00-20:00' }),
    location: 'Southport, Gold Coast',
    specializations: specialization_objects.select { |s| ['Elderly Care', 'Disability Support', 'Community Support', 'Healthcare Support'].include?(s.name) },
  },
]

support_workers.each { |sw| SupportWorker.create!(sw) }
puts "Support workers seeded: #{SupportWorker.count}"
