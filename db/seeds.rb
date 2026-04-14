# db/seeds.rb

# Clear existing data to prevent duplication if re-seeding
if Rails.env.development?
  Appointment.delete_all
  Client.delete_all
  SupportWorker.delete_all
  User.delete_all
end

clients_data = [
  {
    email: 'elena.martinez@example.com',
    first_name: 'Elena', last_name: 'Martinez',
    location: 'Surry Hills, Sydney',
    phone: '0421 210 909',
    health_conditions: 'Hypertension',
    medication: 'Lisinopril', allergies: 'Ibuprofen',
    emergency_contact_first_name: 'Miguel', emergency_contact_last_name: 'Martinez', emergency_contact_phone: '0431 167 474'
  },
  {
    email: 'raj.patel@example.com',
    first_name: 'Raj', last_name: 'Patel',
    location: 'Fitzroy, Melbourne',
    phone: '0422 289 191',
    health_conditions: 'None',
    medication: 'None', allergies: 'Shellfish',
    emergency_contact_first_name: 'Anita', emergency_contact_last_name: 'Patel', emergency_contact_phone: '0423 324 141'
  },
  {
    email: 'amina.ali@example.com',
    first_name: 'Amina', last_name: 'Ali',
    location: 'Fortitude Valley, Brisbane',
    phone: '0424 986 262',
    health_conditions: 'Diabetes',
    medication: 'Metformin', allergies: 'Latex',
    emergency_contact_first_name: 'Yusuf', emergency_contact_last_name: 'Ali', emergency_contact_phone: '0425 542 929'
  },
  {
    email: 'thomas.rivera@example.com',
    first_name: 'Thomas', last_name: 'Rivera',
    location: 'Newtown, Sydney',
    phone: '0426 453 232',
    health_conditions: 'Asthma',
    medication: 'Ventolin', allergies: 'Penicillin',
    emergency_contact_first_name: 'Lucia', emergency_contact_last_name: 'Rivera', emergency_contact_phone: '0427 634 848'
  },
  {
    email: 'mai.nguyen@example.com',
    first_name: 'Mai', last_name: 'Nguyen',
    location: 'South Yarra, Melbourne',
    phone: '0428 748 282',
    health_conditions: 'Epilepsy',
    medication: 'Levetiracetam', allergies: 'Nuts',
    emergency_contact_first_name: 'Duy', emergency_contact_last_name: 'Nguyen', emergency_contact_phone: '0429 869 494'
  },
  {
    email: 'sophie.chen@example.com',
    first_name: 'Sophie', last_name: 'Chen',
    location: 'Parramatta, Sydney',
    phone: '0430 112 345',
    health_conditions: 'Autism spectrum disorder',
    medication: 'None', allergies: 'None',
    emergency_contact_first_name: 'Wei', emergency_contact_last_name: 'Chen', emergency_contact_phone: '0431 223 456'
  },
  {
    email: 'james.obrien@example.com',
    first_name: 'James', last_name: "O'Brien",
    location: 'West End, Brisbane',
    phone: '0432 334 567',
    health_conditions: 'Dementia',
    medication: 'Donepezil', allergies: 'Aspirin',
    emergency_contact_first_name: 'Mary', emergency_contact_last_name: "O'Brien", emergency_contact_phone: '0433 445 678'
  },
]

clients_data.each do |data|
  email = data.delete(:email)
  user = User.create!(email: email, password: 'password123', role: :client)
  Client.create!(data.merge(user: user))
end
puts "Clients seeded: #{Client.count}"


support_workers_data = [
  {
    email: 'olivia.williams@example.com',
    first_name: 'Olivia', last_name: 'Williams',
    bio: 'Passionate about providing quality support to clients. Experienced in aged care and disability services.',
    experience: '7 years working with elderly and disabled clients in the Sydney metro area.',
    phone: '0400 123 456',
    age: 34,
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri], time_window: '08:00-18:00' }),
    location: 'Bondi, Sydney',
    specializations: specialization_objects.select { |s| ['Elderly Care', 'Disability Support'].include?(s.name) },
  },
  {
    email: 'james.smith@example.com',
    first_name: 'James', last_name: 'Smith',
    bio: 'Experienced in mental health and rehabilitation support with a warm, person-centred approach.',
    experience: '5 years in community support across Melbourne.',
    phone: '0400 234 567',
    age: 29,
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri Sat Sun], time_window: '09:00-17:00' }),
    location: 'Richmond, Melbourne',
    specializations: specialization_objects.select { |s| ['Mental Health Support', 'Rehabilitation Support', 'Community Support'].include?(s.name) },
  },
  {
    email: 'priya.sharma@example.com',
    first_name: 'Priya', last_name: 'Sharma',
    bio: 'Dedicated healthcare support worker with specialist training in physical therapy assistance.',
    experience: '4 years in disability and healthcare support in Brisbane.',
    phone: '0401 345 678',
    age: 27,
    availability: JSON.generate({ days: %w[Mon Wed Fri], time_window: '09:00-17:00' }),
    location: 'New Farm, Brisbane',
    specializations: specialization_objects.select { |s| ['Physical Therapy', 'Healthcare Support', 'Disability Support'].include?(s.name) },
  },
  {
    email: 'liam.oconnor@example.com',
    first_name: 'Liam', last_name: "O'Connor",
    bio: 'Compassionate support worker focused on community inclusion and independent living skills.',
    experience: '6 years supporting clients with intellectual disabilities in Perth.',
    phone: '0402 456 789',
    age: 31,
    availability: JSON.generate({ days: %w[Tue Thu Sat Sun], time_window: '10:00-20:00' }),
    location: 'Fremantle, Perth',
    specializations: specialization_objects.select { |s| ['Community Support', 'Disability Support', 'Child Care'].include?(s.name) },
  },
  {
    email: 'mei.zhang@example.com',
    first_name: 'Mei', last_name: 'Zhang',
    bio: 'Child and family support specialist with extensive experience in early intervention programs.',
    experience: '8 years in child care and family support services across Sydney.',
    phone: '0403 567 890',
    age: 36,
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri], time_window: '07:00-15:00' }),
    location: 'Chatswood, Sydney',
    specializations: specialization_objects.select { |s| ['Child Care', 'Community Support', 'Mental Health Support'].include?(s.name) },
  },
  {
    email: 'daniel.torres@example.com',
    first_name: 'Daniel', last_name: 'Torres',
    bio: 'Rehabilitation specialist helping clients regain independence after injury or illness.',
    experience: '5 years in rehabilitation and healthcare support in Adelaide.',
    phone: '0404 678 901',
    age: 30,
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri Sat], time_window: '08:00-16:00' }),
    location: 'Norwood, Adelaide',
    specializations: specialization_objects.select { |s| ['Rehabilitation Support', 'Physical Therapy', 'Healthcare Support'].include?(s.name) },
  },
  {
    email: 'aisha.hassan@example.com',
    first_name: 'Aisha', last_name: 'Hassan',
    bio: 'Empathetic mental health support worker committed to trauma-informed, culturally safe practice.',
    experience: '3 years in mental health and community support in Melbourne.',
    phone: '0405 789 012',
    age: 25,
    availability: JSON.generate({ days: %w[Sat Sun], time_window: '09:00-18:00' }),
    location: 'Brunswick, Melbourne',
    specializations: specialization_objects.select { |s| ['Mental Health Support', 'Community Support'].include?(s.name) },
  },
  {
    email: 'nathan.kowalski@example.com',
    first_name: 'Nathan', last_name: 'Kowalski',
    bio: 'Versatile support worker experienced across aged care, disability, and community programs.',
    experience: '10 years in diverse support roles across the Gold Coast and Brisbane.',
    phone: '0406 890 123',
    age: 42,
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri], time_window: '12:00-20:00' }),
    location: 'Southport, Gold Coast',
    specializations: specialization_objects.select { |s| ['Elderly Care', 'Disability Support', 'Community Support', 'Healthcare Support'].include?(s.name) },
  },
  # ... other support workers ...
]

support_workers_data.each do |data|
  email = data.delete(:email)
  user = User.create!(email: email, password: 'password123', role: :support_worker)
  SupportWorker.create!(data.merge(user: user, email: email, status: 'approved'))
end
puts "Support workers seeded: #{SupportWorker.count}"

User.create!(email: 'admin@example.com', password: 'password123', role: :admin)
puts "Admin seeded."
