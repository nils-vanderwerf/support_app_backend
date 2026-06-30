# db/seeds.rb

require 'openssl'
require 'base64'
require 'securerandom'

# Clear existing data to prevent duplication if re-seeding
if Rails.env.development? || Rails.env.production?
  Review.delete_all
  Message.delete_all
  Conversation.delete_all
  Appointment.delete_all
  Client.delete_all
  SupportWorker.delete_all
  User.delete_all
end

# ---------------------------------------------------------------------------
# Clients
# ---------------------------------------------------------------------------
clients_data = [
  {
    email: 'elena.martinez@example.com',
    first_name: 'Elena', last_name: 'Martinez',
    date_of_birth: Date.new(1978, 4, 12),
    gender: 'Female',
    location: 'Surry Hills, Sydney',
    phone: '0421 210 909',
    bio: 'I live independently in Surry Hills and am looking for regular support with daily living tasks and getting to medical appointments. I enjoy cooking, reading, and being part of my local community.',
    health_conditions: 'Hypertension',
    medication: 'Lisinopril 10mg daily',
    allergies: 'Ibuprofen',
    emergency_contact_first_name: 'Miguel', emergency_contact_last_name: 'Martinez', emergency_contact_phone: '0431 167 474',
  },
  {
    email: 'raj.patel@example.com',
    first_name: 'Raj', last_name: 'Patel',
    date_of_birth: Date.new(1990, 9, 3),
    gender: 'Male',
    location: 'Fitzroy, Melbourne',
    phone: '0422 289 191',
    bio: "Working from home and looking for regular check-ins to stay connected and manage my mental wellbeing. I value genuine conversations over clinical formality.",
    health_conditions: 'None',
    medication: 'None',
    allergies: 'Shellfish',
    emergency_contact_first_name: 'Anita', emergency_contact_last_name: 'Patel', emergency_contact_phone: '0423 324 141',
  },
  {
    email: 'amina.ali@example.com',
    first_name: 'Amina', last_name: 'Ali',
    date_of_birth: Date.new(1985, 7, 22),
    gender: 'Female',
    location: 'Fortitude Valley, Brisbane',
    phone: '0424 986 262',
    bio: 'Managing Type 2 Diabetes and recovering from a knee injury. I need support with physical therapy exercises, blood sugar monitoring, and transport to appointments.',
    health_conditions: 'Type 2 Diabetes, recovering from knee injury',
    medication: 'Metformin 500mg twice daily',
    allergies: 'Latex',
    emergency_contact_first_name: 'Yusuf', emergency_contact_last_name: 'Ali', emergency_contact_phone: '0425 542 929',
  },
  {
    email: 'thomas.rivera@example.com',
    first_name: 'Thomas', last_name: 'Rivera',
    date_of_birth: Date.new(1972, 11, 8),
    gender: 'Male',
    location: 'Newtown, Sydney',
    phone: '0426 453 232',
    bio: 'I have asthma and some social anxiety. Looking for a support worker who can help me stay active in the community — going to markets, libraries, local events.',
    health_conditions: 'Asthma, social anxiety',
    medication: 'Ventolin as needed',
    allergies: 'Penicillin',
    emergency_contact_first_name: 'Lucia', emergency_contact_last_name: 'Rivera', emergency_contact_phone: '0427 634 848',
  },
  {
    email: 'mai.nguyen@example.com',
    first_name: 'Mai', last_name: 'Nguyen',
    date_of_birth: Date.new(1995, 2, 17),
    gender: 'Female',
    location: 'South Yarra, Melbourne',
    phone: '0428 748 282',
    bio: 'I have epilepsy (well managed) and am studying part-time. I need flexible support that works around my schedule — mostly help staying organised and getting out socially.',
    health_conditions: 'Epilepsy (well managed)',
    medication: 'Levetiracetam 500mg twice daily',
    allergies: 'Nuts',
    emergency_contact_first_name: 'Duy', emergency_contact_last_name: 'Nguyen', emergency_contact_phone: '0429 869 494',
  },
  {
    email: 'sophie.chen@example.com',
    first_name: 'Sophie', last_name: 'Chen',
    date_of_birth: Date.new(1999, 6, 30),
    gender: 'Female',
    location: 'Parramatta, Sydney',
    phone: '0430 112 345',
    bio: "I'm on the autism spectrum. I prefer clear, direct communication — no small talk, no surprises. I'm very capable and independent; I just need support with specific tasks and occasional community access.",
    health_conditions: 'Autism spectrum disorder (ASD)',
    medication: 'None',
    allergies: 'None',
    emergency_contact_first_name: 'Wei', emergency_contact_last_name: 'Chen', emergency_contact_phone: '0431 223 456',
  },
  {
    email: 'james.obrien@example.com',
    first_name: 'James', last_name: "O'Brien",
    date_of_birth: Date.new(1945, 3, 5),
    gender: 'Male',
    location: 'West End, Brisbane',
    phone: '0432 334 567',
    bio: 'I have early-stage dementia and live with my daughter. I enjoy gardening, chess, and talking about history. Looking for a support worker who can engage with me and keep my mind active.',
    health_conditions: 'Early-stage dementia',
    medication: 'Donepezil 5mg daily',
    allergies: 'Aspirin',
    emergency_contact_first_name: 'Mary', emergency_contact_last_name: "O'Brien", emergency_contact_phone: '0433 445 678',
  },
]

clients_data.each do |data|
  email = data.delete(:email)
  user = User.create!(email: email, password: 'password123', role: :client)
  Client.create!(data.merge(user: user))
end
puts "Clients seeded: #{Client.count}"

# Admin created early so workers can reference approved_by_id
admin_user = User.create!(email: 'admin@example.com', password: 'password123', role: :admin)
puts "Admin seeded."

# ---------------------------------------------------------------------------
# Specialisations
# ---------------------------------------------------------------------------
specialisations = [
  'Child Care', 'Elderly Care', 'Disability Support', 'Mental Health Support',
  'Rehabilitation Support', 'Community Support', 'Physical Therapy', 'Healthcare Support'
]
specialisation_objects = specialisations.map { |name| Specialisation.find_or_create_by(name: name) }

# ---------------------------------------------------------------------------
# Support Workers
# ---------------------------------------------------------------------------
support_workers_data = [
  {
    email: 'olivia.williams@example.com',
    first_name: 'Olivia', last_name: 'Williams',
    date_of_birth: Date.new(1988, 5, 14),
    gender: 'Female',
    bio: 'Passionate about providing quality support to clients. 7 years of experience in aged care and disability services, with a warm, person-centred approach. I believe everyone deserves to live independently and with dignity.',
    experience: 7,
    phone: '0400 123 456',
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri], time_window: '08:00-18:00' }),
    location: 'Bondi, Sydney',
    police_check_number: 'NSW2024-PC-88341',
    police_check_expiry: Date.new(2026, 8, 15),
    wwcc_number: 'WWC0294817E',
    wwcc_expiry: Date.new(2027, 3, 20),
    agent_recommendation: 'Approved — strong communication, verified credentials, 7 years experience in aged care and disability. Highly recommended.',
    specialisations: specialisation_objects.select { |s| ['Elderly Care', 'Disability Support', 'Healthcare Support'].include?(s.name) },
  },
  {
    email: 'james.smith@example.com',
    first_name: 'James', last_name: 'Smith',
    date_of_birth: Date.new(1984, 11, 2),
    gender: 'Male',
    bio: 'Experienced in mental health and rehabilitation support with a warm, person-centred approach. I believe in meeting people where they are — no jargon, no judgment. 5 years supporting people through anxiety, depression, and recovery.',
    experience: 5,
    phone: '0400 234 567',
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri Sat Sun], time_window: '09:00-17:00' }),
    location: 'Richmond, Melbourne',
    police_check_number: 'VIC2023-PC-44219',
    police_check_expiry: Date.new(2026, 6, 10),
    wwcc_number: 'WWC0187634E',
    wwcc_expiry: Date.new(2026, 11, 5),
    agent_recommendation: 'Approved — valid credentials, strong background in mental health and community support. Recommended for approval.',
    specialisations: specialisation_objects.select { |s| ['Mental Health Support', 'Rehabilitation Support', 'Community Support'].include?(s.name) },
  },
  {
    email: 'priya.sharma@example.com',
    first_name: 'Priya', last_name: 'Sharma',
    date_of_birth: Date.new(1991, 8, 25),
    gender: 'Female',
    bio: 'Dedicated healthcare support worker with specialist training in physical therapy assistance. I work closely with physiotherapists to help clients complete their home exercise programs and regain mobility.',
    experience: 4,
    phone: '0401 345 678',
    availability: JSON.generate({ days: %w[Mon Wed Fri], time_window: '09:00-17:00' }),
    location: 'New Farm, Brisbane',
    police_check_number: 'QLD2024-PC-61033',
    police_check_expiry: Date.new(2027, 1, 8),
    wwcc_number: 'WWC0341209E',
    wwcc_expiry: Date.new(2027, 6, 14),
    agent_recommendation: 'Approved — healthcare credentials verified, physical therapy background confirmed. Clear to work.',
    specialisations: specialisation_objects.select { |s| ['Physical Therapy', 'Healthcare Support', 'Disability Support'].include?(s.name) },
  },
  {
    email: 'liam.oconnor@example.com',
    first_name: 'Liam', last_name: "O'Connor",
    date_of_birth: Date.new(1986, 3, 19),
    gender: 'Male',
    bio: 'Compassionate support worker focused on community inclusion and independent living skills. I help clients build confidence, make connections, and participate in everyday activities on their own terms.',
    experience: 6,
    phone: '0402 456 789',
    availability: JSON.generate({ days: %w[Tue Thu Sat Sun], time_window: '10:00-20:00' }),
    location: 'Fremantle, Perth',
    police_check_number: 'WA2023-PC-29876',
    police_check_expiry: Date.new(2025, 12, 31),
    wwcc_number: 'WWC0229441E',
    wwcc_expiry: Date.new(2026, 4, 22),
    agent_recommendation: 'Approved — solid community support background. Note: police check expiring Dec 2025, renewal recommended.',
    specialisations: specialisation_objects.select { |s| ['Community Support', 'Disability Support', 'Child Care'].include?(s.name) },
  },
  {
    email: 'mei.zhang@example.com',
    first_name: 'Mei', last_name: 'Zhang',
    date_of_birth: Date.new(1983, 12, 7),
    gender: 'Female',
    bio: 'Child and family support specialist with 8 years of experience, including extensive work with people on the autism spectrum. I use direct, structured communication and always follow the client\'s lead.',
    experience: 8,
    phone: '0403 567 890',
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri], time_window: '07:00-15:00' }),
    location: 'Chatswood, Sydney',
    police_check_number: 'NSW2024-PC-72190',
    police_check_expiry: Date.new(2027, 5, 3),
    wwcc_number: 'WWC0398812E',
    wwcc_expiry: Date.new(2027, 9, 17),
    agent_recommendation: 'Approved — extensive ASD and child care background, exemplary record. Highly recommended.',
    specialisations: specialisation_objects.select { |s| ['Child Care', 'Community Support', 'Mental Health Support', 'Disability Support'].include?(s.name) },
  },
  {
    email: 'daniel.torres@example.com',
    first_name: 'Daniel', last_name: 'Torres',
    date_of_birth: Date.new(1989, 7, 14),
    gender: 'Male',
    bio: 'Rehabilitation specialist helping clients regain independence after injury or illness. I coordinate with medical teams to deliver consistent, goal-focused support that gets results.',
    experience: 5,
    phone: '0404 678 901',
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri Sat], time_window: '08:00-16:00' }),
    location: 'Norwood, Adelaide',
    police_check_number: 'SA2023-PC-53412',
    police_check_expiry: Date.new(2026, 9, 28),
    wwcc_number: 'WWC0276530E',
    wwcc_expiry: Date.new(2026, 12, 11),
    agent_recommendation: 'Approved — rehabilitation credentials verified. Recommended.',
    specialisations: specialisation_objects.select { |s| ['Rehabilitation Support', 'Physical Therapy', 'Healthcare Support'].include?(s.name) },
  },
  {
    email: 'aisha.hassan@example.com',
    first_name: 'Aisha', last_name: 'Hassan',
    date_of_birth: Date.new(1993, 1, 28),
    gender: 'Female',
    bio: 'Empathetic mental health support worker committed to trauma-informed, culturally safe practice. I work primarily on weekends and support clients from diverse backgrounds who need flexible, respectful care.',
    experience: 3,
    phone: '0405 789 012',
    availability: JSON.generate({ days: %w[Sat Sun], time_window: '09:00-18:00' }),
    location: 'Brunswick, Melbourne',
    police_check_number: 'VIC2024-PC-91027',
    police_check_expiry: Date.new(2027, 2, 14),
    wwcc_number: 'WWC0412876E',
    wwcc_expiry: Date.new(2027, 7, 30),
    agent_recommendation: 'Approved — trauma-informed background, culturally safe practice noted. Clear to work.',
    specialisations: specialisation_objects.select { |s| ['Mental Health Support', 'Community Support'].include?(s.name) },
  },
  {
    email: 'nathan.kowalski@example.com',
    first_name: 'Nathan', last_name: 'Kowalski',
    date_of_birth: Date.new(1980, 10, 15),
    gender: 'Male',
    bio: 'Versatile support worker with 10 years across aged care, disability, and community programs. I bring calm, consistency, and good humour to every session — my clients know they can count on me.',
    experience: 10,
    phone: '0406 890 123',
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri], time_window: '12:00-20:00' }),
    location: 'Southport, Gold Coast',
    police_check_number: 'QLD2023-PC-38904',
    police_check_expiry: Date.new(2026, 7, 19),
    wwcc_number: 'WWC0163345E',
    wwcc_expiry: Date.new(2026, 10, 8),
    agent_recommendation: 'Approved — 10 years experience, clean record across multiple states. Highly recommended.',
    specialisations: specialisation_objects.select { |s| ['Elderly Care', 'Disability Support', 'Community Support', 'Healthcare Support'].include?(s.name) },
  },
  {
    email: 'tom.nguyen@example.com',
    first_name: 'Tom', last_name: 'Nguyen',
    date_of_birth: Date.new(1990, 6, 3),
    gender: 'Male',
    bio: 'Disability support specialist based in Marrickville with 6 years experience supporting adults with physical and intellectual disabilities. I focus on building independence through daily routines, community access, and skill development. Bilingual in English and Vietnamese.',
    experience: 6,
    phone: '0407 112 334',
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri Sat], time_window: '08:00-17:00' }),
    location: 'Marrickville, Sydney',
    police_check_number: 'NSW2024-PC-55203',
    police_check_expiry: Date.new(2027, 4, 9),
    wwcc_number: 'WWC0462183E',
    wwcc_expiry: Date.new(2027, 10, 2),
    agent_recommendation: 'Approved — strong disability support background, bilingual capability noted. Credentials valid. Highly recommended.',
    specialisations: specialisation_objects.select { |s| ['Disability Support', 'Community Support', 'Rehabilitation Support'].include?(s.name) },
  },
  {
    email: 'sarah.okafor@example.com',
    first_name: 'Sarah', last_name: 'Okafor',
    date_of_birth: Date.new(1987, 2, 18),
    gender: 'Female',
    bio: 'Experienced disability and mental health support worker based in Blacktown. I specialise in supporting clients with dual diagnoses — physical disability alongside anxiety or depression — helping them stay connected to their community and goals.',
    experience: 8,
    phone: '0408 223 445',
    availability: JSON.generate({ days: %w[Mon Tue Thu Fri Sun], time_window: '09:00-19:00' }),
    location: 'Blacktown, Sydney',
    police_check_number: 'NSW2023-PC-41876',
    police_check_expiry: Date.new(2026, 11, 17),
    wwcc_number: 'WWC0335671E',
    wwcc_expiry: Date.new(2027, 1, 28),
    agent_recommendation: 'Approved — dual diagnosis experience is a strong differentiator. Credentials in order. Recommended.',
    specialisations: specialisation_objects.select { |s| ['Disability Support', 'Mental Health Support', 'Community Support'].include?(s.name) },
  },
  {
    email: 'chris.deluca@example.com',
    first_name: 'Chris', last_name: 'DeLuca',
    date_of_birth: Date.new(1995, 11, 29),
    gender: 'Male',
    bio: 'Support worker based in Manly specialising in physical disability and healthcare support. I have a Certificate IV in Disability and experience assisting clients with mobility aids, personal care, and transport. Happy to travel across the Northern Beaches.',
    experience: 3,
    phone: '0409 334 556',
    availability: JSON.generate({ days: %w[Mon Wed Thu Fri Sat], time_window: '07:00-15:00' }),
    location: 'Manly, Sydney',
    police_check_number: 'NSW2025-PC-67041',
    police_check_expiry: Date.new(2028, 3, 14),
    wwcc_number: 'WWC0521034E',
    wwcc_expiry: Date.new(2028, 6, 5),
    agent_recommendation: 'Approved — Certificate IV verified, clean record, good availability. Suitable for physical disability and personal care roles.',
    specialisations: specialisation_objects.select { |s| ['Disability Support', 'Healthcare Support', 'Physical Therapy'].include?(s.name) },
  },
  {
    email: 'grace.ali@example.com',
    first_name: 'Grace', last_name: 'Ali',
    date_of_birth: Date.new(1985, 9, 11),
    gender: 'Female',
    bio: 'Based in Liverpool, I support clients with complex needs across the south-west Sydney region. 9 years in disability services, including SIL and community access. I have experience with complex behaviour support plans and work closely with coordinators and families.',
    experience: 9,
    phone: '0410 445 667',
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri], time_window: '08:00-16:00' }),
    location: 'Liverpool, Sydney',
    police_check_number: 'NSW2024-PC-30917',
    police_check_expiry: Date.new(2027, 7, 22),
    wwcc_number: 'WWC0408892E',
    wwcc_expiry: Date.new(2027, 12, 14),
    agent_recommendation: 'Approved — 9 years experience, SIL and complex behaviour support background. Highly recommended for clients with complex needs.',
    specialisations: specialisation_objects.select { |s| ['Disability Support', 'Community Support', 'Mental Health Support', 'Healthcare Support'].include?(s.name) },
  },
]

support_workers_data.each do |data|
  email = data.delete(:email)
  user = User.create!(email: email, password: 'password123', role: :support_worker)
  SupportWorker.create!(data.merge(user: user, email: email, status: 'approved', approved_by_id: admin_user.id))
end

# Pending applicants — visible in admin /admin dashboard for approval
pending_workers_data = [
  {
    email: 'marcus.bell@example.com',
    first_name: 'Marcus', last_name: 'Bell',
    date_of_birth: Date.new(1993, 4, 7),
    gender: 'Male',
    bio: 'Former nurse with 3 years experience transitioning into disability support. Comfortable with complex health needs, manual handling, and working alongside allied health professionals.',
    experience: 3,
    phone: '0403 711 822',
    availability: JSON.generate({ days: %w[Mon Tue Wed Thu Fri], time_window: '07:00-15:00' }),
    location: 'Newtown, Sydney',
    police_check_number: 'NSW2025-PC-10482',
    police_check_expiry: Date.new(2028, 2, 20),
    wwcc_number: 'WWC0501923E',
    wwcc_expiry: Date.new(2028, 5, 11),
    agent_recommendation: 'Approved — nursing background adds strong clinical credibility. Police check and WWCC both valid. Recommended for approval.',
    specialisations: specialisation_objects.select { |s| ['Healthcare Support', 'Disability Support', 'Rehabilitation Support'].include?(s.name) },
  },
  {
    email: 'aisha.koroma@example.com',
    first_name: 'Aisha', last_name: 'Koroma',
    date_of_birth: Date.new(1997, 9, 22),
    gender: 'Female',
    bio: 'Community worker with a background in youth mental health. Passionate about early intervention and helping young people build resilience and social skills. Fluent in English and French.',
    experience: 2,
    phone: '0404 863 140',
    availability: JSON.generate({ days: %w[Mon Wed Thu Fri Sat], time_window: '10:00-18:00' }),
    location: 'Parramatta, Sydney',
    police_check_number: 'NSW2024-PC-93017',
    police_check_expiry: Date.new(2027, 11, 3),
    wwcc_number: 'WWC0489274E',
    wwcc_expiry: Date.new(2027, 8, 16),
    agent_recommendation: 'Conditionally approved — credentials verified and communication is strong. Limited experience (2 years) but youth mental health focus is genuine. Recommend pairing with an experienced worker initially.',
    specialisations: specialisation_objects.select { |s| ['Mental Health Support', 'Child Care', 'Community Support'].include?(s.name) },
  },
]

pending_workers_data.each do |data|
  email = data.delete(:email)
  user = User.create!(email: email, password: 'password123', role: :support_worker)
  SupportWorker.create!(data.merge(user: user, email: email, status: 'pending'))
end
puts "Support workers seeded: #{SupportWorker.count} (#{SupportWorker.pending_approval.count} pending)"

# ---------------------------------------------------------------------------
# Appointments
# ---------------------------------------------------------------------------
elena   = Client.find_by!(first_name: 'Elena')
raj     = Client.find_by!(first_name: 'Raj')
amina   = Client.find_by!(first_name: 'Amina')
thomas  = Client.find_by!(first_name: 'Thomas')
mai     = Client.find_by!(first_name: 'Mai')
sophie  = Client.find_by!(first_name: 'Sophie')

olivia  = SupportWorker.find_by!(first_name: 'Olivia')
james   = SupportWorker.find_by!(first_name: 'James', last_name: 'Smith')
priya   = SupportWorker.find_by!(first_name: 'Priya')
mei_sw  = SupportWorker.find_by!(first_name: 'Mei')
nathan  = SupportWorker.find_by!(first_name: 'Nathan')
daniel  = SupportWorker.find_by!(first_name: 'Daniel')

appointments_data = [
  # Past — approved
  { client: elena,  support_worker: olivia,  date: 30.days.ago,  duration: 60,  location: 'Surry Hills Community Centre', notes: 'Initial assessment session',           status: 'approved' },
  { client: elena,  support_worker: olivia,  date: 23.days.ago,  duration: 90,  location: 'Surry Hills Community Centre', notes: 'Daily living skills practice',         status: 'approved' },
  { client: elena,  support_worker: olivia,  date: 16.days.ago,  duration: 60,  location: 'Client home, Surry Hills',     notes: 'Medication management review',         status: 'approved' },
  { client: elena,  support_worker: olivia,  date: 9.days.ago,   duration: 90,  location: 'Surry Hills Community Centre', notes: 'Community access outing',              status: 'approved' },
  { client: elena,  support_worker: olivia,  date: 2.days.ago,   duration: 90,  location: 'Surry Hills Community Centre', notes: 'Weekly support session',               status: 'approved' },

  { client: raj,    support_worker: james,   date: 28.days.ago,  duration: 60,  location: 'Swan Street Cafe, Richmond',   notes: 'Informal coffee catch-up / check-in',  status: 'approved' },
  { client: raj,    support_worker: james,   date: 14.days.ago,  duration: 60,  location: 'Fitzroy Community Hub',         notes: 'Goal-setting session',                status: 'approved' },

  { client: amina,  support_worker: priya,   date: 21.days.ago,  duration: 120, location: 'New Farm Physio Centre',        notes: 'Physical therapy assistance',         status: 'approved' },
  { client: amina,  support_worker: priya,   date: 7.days.ago,   duration: 90,  location: 'New Farm Physio Centre',        notes: 'Post-session review & exercises',     status: 'approved' },

  { client: thomas, support_worker: olivia,  date: 18.days.ago,  duration: 60,  location: 'Newtown Library',               notes: 'Community access — library visit',    status: 'approved' },
  { client: thomas, support_worker: olivia,  date: 4.days.ago,   duration: 60,  location: 'Newtown Farmers Market',        notes: 'Community outing — farmers market',   status: 'approved' },

  { client: sophie, support_worker: mei_sw,  date: 25.days.ago,  duration: 90,  location: 'Parramatta Support Hub',        notes: 'Sensory integration activities',      status: 'approved' },
  { client: sophie, support_worker: mei_sw,  date: 11.days.ago,  duration: 60,  location: 'Parramatta Support Hub',        notes: 'Communication skills session',        status: 'approved' },
  { client: sophie, support_worker: mei_sw,  date: 3.days.ago,   duration: 90,  location: 'Parramatta Support Hub',        notes: 'Weekly skills session',               status: 'approved' },

  { client: mai,    support_worker: nathan,  date: 20.days.ago,  duration: 60,  location: 'South Yarra Day Centre',        notes: 'Epilepsy management & social goals',  status: 'approved' },
  { client: mai,    support_worker: nathan,  date: 6.days.ago,   duration: 60,  location: 'South Yarra Community Park',    notes: 'Social inclusion outing',             status: 'approved' },

  # Upcoming — approved
  { client: elena,  support_worker: olivia,  date: 5.days.from_now,  duration: 90,  location: 'Surry Hills Community Centre', notes: 'Weekly support session',           status: 'approved' },
  { client: elena,  support_worker: olivia,  date: 12.days.from_now, duration: 90,  location: 'Surry Hills Community Centre', notes: 'Weekly support session',           status: 'approved' },
  { client: elena,  support_worker: olivia,  date: 19.days.from_now, duration: 90,  location: 'Surry Hills Community Centre', notes: 'Weekly support session',           status: 'approved' },

  { client: raj,    support_worker: james,   date: 7.days.from_now,  duration: 60,  location: 'Fitzroy Community Hub',         notes: 'Fortnightly check-in',            status: 'approved' },

  { client: amina,  support_worker: priya,   date: 4.days.from_now,  duration: 120, location: 'New Farm Physio Centre',        notes: 'Ongoing physical therapy support', status: 'approved' },

  { client: sophie, support_worker: mei_sw,  date: 8.days.from_now,  duration: 90,  location: 'Parramatta Support Hub',        notes: 'Weekly skills session',            status: 'approved' },
  { client: sophie, support_worker: mei_sw,  date: 15.days.from_now, duration: 90,  location: 'Parramatta Support Hub',        notes: 'Weekly skills session',            status: 'approved' },

  { client: mai,    support_worker: nathan,  date: 9.days.from_now,  duration: 60,  location: 'South Yarra Day Centre',        notes: 'Support & social inclusion',       status: 'approved' },

  { client: thomas, support_worker: olivia,  date: 11.days.from_now, duration: 60,  location: 'Newtown Library',               notes: 'Community access outing',          status: 'approved' },

  # Upcoming — pending invitations
  { client: elena,  support_worker: olivia,  date: 26.days.from_now, duration: 90,  location: 'Surry Hills Community Centre', notes: 'Monthly review session',           status: 'pending' },
  { client: raj,    support_worker: james,   date: 21.days.from_now, duration: 60,  location: 'Fitzroy Community Hub',         notes: 'Monthly check-in',                status: 'pending' },
  { client: amina,  support_worker: daniel,  date: 14.days.from_now, duration: 60,  location: 'TBD',                           notes: 'Rehabilitation assessment',        status: 'pending' },
]

appointments_data.each do |data|
  Appointment.create!(
    client:         data[:client],
    support_worker: data[:support_worker],
    date:           data[:date],
    duration:       data[:duration],
    location:       data[:location],
    notes:          data[:notes],
    status:         data[:status],
  )
end
puts "Appointments seeded: #{Appointment.count}"

# ---------------------------------------------------------------------------
# Conversations & Messages (encrypted, mirrors ConversationsController)
# ---------------------------------------------------------------------------
SEED_ENCRYPTION_CONTEXT = 'support-app-messages-v1'

def encrypt_msg(plaintext, conversation_id)
  prk = OpenSSL::HMAC.digest('SHA256', SEED_ENCRYPTION_CONTEXT, SEED_ENCRYPTION_CONTEXT)
  key = OpenSSL::HMAC.digest('SHA256', prk, "conv-#{conversation_id}\x01")[0, 32]
  iv  = SecureRandom.random_bytes(12)
  cipher = OpenSSL::Cipher.new('aes-256-gcm')
  cipher.encrypt
  cipher.key      = key
  cipher.iv       = iv
  cipher.auth_data = ''
  ciphertext = cipher.update(plaintext) + cipher.final
  tag = cipher.auth_tag
  'ENC:' + Base64.strict_encode64(iv + ciphertext + tag)
end

def seed_messages(conv, turns)
  turns.each_with_index do |(type, sender, text), i|
    created_at = turns.length.days.ago + (i * 4).hours
    if type == :sys
      conv.messages.create!(
        content:     encrypt_msg("[SYS]#{text}", conv.id),
        sender_type: sender == :sw ? 'support_worker' : 'client',
        sender_id:   sender == :sw ? conv.support_worker_id : conv.client_id,
        created_at:  created_at,
      )
    else
      conv.messages.create!(
        content:     encrypt_msg(text, conv.id),
        sender_type: type == :sw ? 'support_worker' : 'client',
        sender_id:   type == :sw ? conv.support_worker_id : conv.client_id,
        created_at:  created_at,
      )
    end
  end
end

# --- Conv 1: Elena (Surry Hills) ↔ Olivia (Bondi) — warm ongoing relationship ---
conv1 = Conversation.create!(client: elena, support_worker: olivia)
seed_messages(conv1, [
  [:client, nil, "Hi Olivia, I'm Elena. I found your profile on Suppova and I'd love to chat about working together."],
  [:sw,     nil, "Hi Elena! Great to connect with you. I can see you're in Surry Hills — that's really close to me in Bondi. I'd love to hear more about what kind of support you're looking for."],
  [:client, nil, "I have hypertension and some harder days where daily tasks feel overwhelming. Mainly looking for help with household tasks, getting to medical appointments, and just having some regular, reliable support."],
  [:sw,     nil, "That all sounds very manageable, and daily living support is exactly my area. How does a weekly session sound to start — just to build a routine and get a feel for things?"],
  [:client, nil, "That sounds great. What days are you free?"],
  [:sw,     nil, "I'm available Monday through Friday. How does Wednesday morning work? We could meet at the Surry Hills Community Centre to start — neutral ground is often easier."],
  [:client, nil, "Wednesday at 10am works perfectly for me."],
  [:sw,     nil, "Perfect — I'll send a formal invitation through now."],
  [:sys,    :sw, "✓ Appointment invitation sent for Wednesday at 10:00 AM."],
  [:client, nil, "Got it, thank you! Should I bring anything?"],
  [:sw,     nil, "Just yourself and any health documents you'd like me to be aware of — nothing formal, just so I can support you properly. Really looking forward to meeting you, Elena!"],
  [:client, nil, "See you Wednesday 😊"],
  [:sw,     nil, "See you then! Feel free to message me anytime before if anything comes up."],
])

# --- Conv 2: Elena (Surry Hills, Sydney) ↔ James (Richmond, Melbourne) — distance decline ---
conv2 = Conversation.create!(client: elena, support_worker: james)
seed_messages(conv2, [
  [:client, nil, "Hi James, I came across your profile and was wondering if you're taking on new clients?"],
  [:sw,     nil, "Hi Elena! Thanks for reaching out — I should be upfront with you straight away. I can see you're in Surry Hills, Sydney, and I'm based in Richmond, Melbourne. That's nearly 900km apart. I don't think I could provide you with the consistent, reliable support you deserve from that distance. I'd really recommend using the location filter on Suppova to find someone in the Sydney area who can be there for you regularly."],
  [:client, nil, "Oh wow, I didn't even clock you were in Melbourne! Yeah that's way too far, thanks for being honest about it."],
  [:sw,     nil, "Of course — better to know upfront than waste each other's time! Best of luck finding the right person, Elena. Sydney has some great support workers on here. Take care of yourself 😊"],
  [:client, nil, "Thanks James, appreciate it!"],
])

# --- Conv 3: Raj (Fitzroy) ↔ James (Richmond) — same city, pushback on clinical tone ---
conv3 = Conversation.create!(client: raj, support_worker: james)
seed_messages(conv3, [
  [:client, nil, "Hey James. Looking for some mental health support — not therapy, just someone to check in with regularly."],
  [:sw,     nil, "Hi Raj! Great to connect. I'd love to help. Could you tell me a bit about your presenting challenges and what therapeutic outcomes you're hoping to achieve?"],
  [:client, nil, "...I'm going to stop you there. 'Presenting challenges' and 'therapeutic outcomes' — that's exactly the kind of language I'm trying to avoid. I just want someone to talk to, not be assessed."],
  [:sw,     nil, "You're completely right — I'm sorry about that. I'll drop the clinical hat. What's been on your mind lately?"],
  [:client, nil, "That's better, thanks. Honestly just been feeling a bit isolated. Working from home, not seeing people much. It grinds you down."],
  [:sw,     nil, "Yeah, it really does — especially over time. I'm in Richmond, so not far from Fitzroy at all. Want to just grab a coffee somewhere and talk? No structure, no agenda."],
  [:client, nil, "Coffee sounds exactly right. When works for you?"],
  [:sw,     nil, "How about Saturday morning? There's a good spot on Swan Street — relaxed, not too loud."],
  [:client, nil, "Perfect. Let's lock it in."],
  [:sw,     nil, "I'll send a booking through — looking forward to it, Raj."],
  [:sys,    :sw, "✓ Appointment invitation sent for Saturday at 10:00 AM."],
])

# --- Conv 4: Sophie (Parramatta) ↔ Mei (Chatswood) — direct ASD communication ---
conv4 = Conversation.create!(client: sophie, support_worker: mei_sw)
seed_messages(conv4, [
  [:client, nil, "Hi. I'm autistic and I need a support worker who actually understands what that means. Do you have real experience with ASD, not just the theory?"],
  [:sw,     nil, "Hi Sophie. Yes — I've worked extensively with people on the autism spectrum for the past 8 years. But I'll also say: autism means different things for different people, so what matters more to me is understanding what it means for you specifically. What does good support look like for you?"],
  [:client, nil, "Good answer. I need clear communication, no surprises, and no small talk. If plans change, tell me in advance. If you don't know something, say so."],
  [:sw,     nil, "Understood — and I mean that literally. I'll always tell you exactly what we're doing, flag any changes early, and I won't pretend to know things I don't. When would you like to start?"],
  [:client, nil, "As soon as possible. I'm in Parramatta. I prefer mornings."],
  [:sw,     nil, "I'm in Chatswood — about 25 minutes by train. I'm happy to come to you. How does next Tuesday at 9am at the Parramatta Support Hub sound?"],
  [:client, nil, "That works. Send the invitation."],
  [:sw,     nil, "Done — sending it through now."],
  [:sys,    :sw, "✓ Appointment invitation sent for Tuesday at 9:00 AM."],
  [:client, nil, "Received. See you then."],
  [:sw,     nil, "See you Tuesday, Sophie. If anything changes before then, I'll let you know immediately."],
])

puts "Conversations seeded: #{Conversation.count}"
puts "Messages seeded: #{Message.count}"

# ---------------------------------------------------------------------------
# Visit Reports
# ---------------------------------------------------------------------------

# Elena Martinez — 5 past appointments with Olivia
elena_past_appts = Appointment.where(client: elena, support_worker: olivia)
                              .where('date < ?', Time.now).order(:date)
elena_visit_data = [
  { activities: 'Initial assessment session. Reviewed client goals, health history, and daily living needs.',
    observations: 'Elena was welcoming and communicative. Hypertension well-managed, no concerns noted. Highly motivated to maintain independence.',
    follow_up_actions: 'Confirm medication schedule and next GP check-up date.' },
  { activities: 'Daily living skills practice — meal planning, grocery list preparation, light housekeeping.',
    observations: 'Client engaged well. Mentioned occasional morning dizziness, possibly related to Lisinopril timing.',
    follow_up_actions: 'Discuss medication timing with GP. Monitor morning dizziness at next visit.' },
  { activities: 'Medication management review. Walked through Lisinopril schedule and discussed storage and reminders.',
    observations: 'Elena confirmed morning dizziness has reduced after adjusting medication timing. Positive mood throughout.',
    follow_up_actions: 'Continue monitoring. Confirm GP follow-up outcome at next appointment.' },
  { activities: 'Community access outing to Surry Hills Farmers Market. Assisted with transport and social navigation.',
    observations: 'Client appeared confident and enjoyed the outing. Connected with a neighbour she hadn\'t seen in months.',
    follow_up_actions: 'Explore regular weekly community outings as part of ongoing support plan.' },
  { activities: 'Weekly support session — cooking, household organisation, social goals check-in.',
    observations: 'Elena reported feeling more confident managing daily tasks independently. Strong overall progress noted.',
    follow_up_actions: 'Review support plan at next session. Consider reducing session frequency if progress continues.' },
]
elena_past_appts.each_with_index do |appt, i|
  VisitReport.create!(
    appointment: appt, user_id: olivia.user_id, client_id: elena.id,
    date: appt.date, **elena_visit_data[i]
  )
end

# Raj Patel — 2 past appointments with James Smith
raj_past_appts = Appointment.where(client: raj, support_worker: james)
                            .where('date < ?', Time.now).order(:date)
raj_visit_data = [
  { activities: 'Informal coffee catch-up at Swan Street Cafe. Open conversation about daily life and social connection.',
    observations: 'Raj opened up about feeling isolated working from home. Good rapport established quickly. No clinical concerns.',
    follow_up_actions: 'Plan a structured goal-setting session for next visit. Explore community activities Raj might enjoy.' },
  { activities: 'Goal-setting session at Fitzroy Community Hub. Identified three social and wellbeing goals for the next month.',
    observations: 'Raj was engaged and practical about his goals. Mood noticeably improved compared to first visit. Isolation less prominent.',
    follow_up_actions: 'Check in on progress against goals at next session. Raj expressed interest in a local book group.' },
]
raj_past_appts.each_with_index do |appt, i|
  VisitReport.create!(
    appointment: appt, user_id: james.user_id, client_id: raj.id,
    date: appt.date, **raj_visit_data[i]
  )
end

# Amina Ali — 2 past appointments with Priya
amina_past_appts = Appointment.where(client: amina, support_worker: priya)
                              .where('date < ?', Time.now).order(:date)
amina_visit_data = [
  { activities: 'Physical therapy assistance at New Farm Physio Centre. Supported client through prescribed knee rehabilitation exercises.',
    observations: 'Amina found exercises challenging but persisted well. Blood sugar stable throughout session. Knee remains swollen post-exercise.',
    follow_up_actions: 'Confirm icing and elevation routine at home. Follow up with physiotherapist on swelling before next session.' },
  { activities: 'Post-session review and home exercise program. Reviewed physio notes and practised modified exercises at lower intensity.',
    observations: 'Swelling has reduced. Amina completing home exercises consistently. Blood sugar monitoring routine now well-established.',
    follow_up_actions: 'Confirm next physio appointment. Encourage Amina to log blood sugar readings for GP review.' },
]
amina_past_appts.each_with_index do |appt, i|
  VisitReport.create!(
    appointment: appt, user_id: priya.user_id, client_id: amina.id,
    date: appt.date, **amina_visit_data[i]
  )
end

# Sophie Chen — 3 past appointments with Mei
sophie_past_appts = Appointment.where(client: sophie, support_worker: mei_sw)
                               .where('date < ?', Time.now).order(:date)
sophie_visit_data = [
  { activities: 'Sensory integration activities at Parramatta Support Hub. Structured tasks chosen in advance and shared with Sophie beforehand.',
    observations: 'Sophie engaged confidently with all planned activities. No sensory overload incidents. Responded positively to clear advance communication.',
    follow_up_actions: 'Continue sharing session plans 24 hours in advance. Introduce one new activity next session with prior notice.' },
  { activities: 'Communication skills session focusing on workplace scenarios and assertive communication strategies.',
    observations: 'Sophie demonstrated strong understanding and practical skill. Articulated personal communication preferences clearly to support worker.',
    follow_up_actions: 'Source workplace communication resources Sophie requested. Plan next session around a community access scenario.' },
  { activities: 'Weekly skills session — community access practice at Parramatta library and independent task completion.',
    observations: 'Sophie navigated the library independently with minimal prompting. Completed all tasks on the agreed checklist. High level of satisfaction reported.',
    follow_up_actions: 'Discuss expanding community access to one additional venue next month. Review support plan goals.' },
]
sophie_past_appts.each_with_index do |appt, i|
  VisitReport.create!(
    appointment: appt, user_id: mei_sw.user_id, client_id: sophie.id,
    date: appt.date, **sophie_visit_data[i]
  )
end

# Mai Nguyen — 2 past appointments with Nathan
mai_past_appts = Appointment.where(client: mai, support_worker: nathan)
                            .where('date < ?', Time.now).order(:date)
mai_visit_data = [
  { activities: 'Epilepsy management discussion and social goal planning at South Yarra Day Centre.',
    observations: 'Mai was calm and engaged. No seizure activity observed. Managing study schedule well but expressed concern about social isolation.',
    follow_up_actions: 'Identify one regular social activity that fits around study timetable. Check in on medication adherence next visit.' },
  { activities: 'Social inclusion outing to South Yarra Community Park. Assisted with transport and social navigation.',
    observations: 'Mai connected positively with other park visitors. Reported feeling less isolated. Medication adherence confirmed, no seizures since last visit.',
    follow_up_actions: 'Explore joining a local study group or hobby class. Continue weekly social outings.' },
]
mai_past_appts.each_with_index do |appt, i|
  VisitReport.create!(
    appointment: appt, user_id: nathan.user_id, client_id: mai.id,
    date: appt.date, **mai_visit_data[i]
  )
end

# Thomas Rivera — 2 past appointments with Olivia
thomas_past_appts = Appointment.where(client: thomas, support_worker: olivia)
                               .where('date < ?', Time.now).order(:date)
thomas_visit_data = [
  { activities: 'Community access visit to Newtown Library. Assisted with transport and social navigation in a busy public space.',
    observations: 'Thomas initially anxious on arrival but settled well once inside. Browsed independently for 30 minutes — a positive step. No asthma episodes.',
    follow_up_actions: 'Continue gradual community exposure. Suggest returning to the library monthly to build familiarity.' },
  { activities: 'Community outing to Newtown Farmers Market. Supported client in browsing stalls and managing crowded environment.',
    observations: 'Thomas was more relaxed than previous outing. Initiated conversation with a market vendor unprompted — notable progress for social anxiety.',
    follow_up_actions: 'Build on unprompted social interactions. Explore other regular local events as future outings.' },
]
thomas_past_appts.each_with_index do |appt, i|
  VisitReport.create!(
    appointment: appt, user_id: olivia.user_id, client_id: thomas.id,
    date: appt.date, **thomas_visit_data[i]
  )
end

puts "Visit reports seeded: #{VisitReport.count}"

# ---------------------------------------------------------------------------
# Reviews
# ---------------------------------------------------------------------------

# Elena reviews Olivia — 3 of her 5 past appointments reviewed
elena_olivia_appts = Appointment.where(client: elena, support_worker: olivia)
                                .where('date < ?', Time.now).order(:date)

[
  { appt: elena_olivia_appts[0], rating: 5, comment: "Olivia made me feel completely at ease from the very first session. She was warm, professional, and clearly knew what she was doing. I felt heard and respected throughout." },
  { appt: elena_olivia_appts[1], rating: 5, comment: "Incredible session — Olivia helped me work through tasks I've been putting off for months. She has a calm, encouraging energy that makes everything feel manageable." },
  { appt: elena_olivia_appts[2], rating: 4, comment: "Really positive visit. Olivia was thorough with the medication review and made sure I understood everything. Only minor thing is we ran slightly over time, but not a big deal at all." },
].each do |r|
  Review.create!(client: elena, support_worker: olivia, appointment: r[:appt], rating: r[:rating], comment: r[:comment])
end

# Thomas reviews Olivia — 1 of 2 past appointments reviewed
thomas_olivia_appts = Appointment.where(client: thomas, support_worker: olivia)
                                 .where('date < ?', Time.now).order(:date)

Review.create!(
  client: thomas, support_worker: olivia,
  appointment: thomas_olivia_appts.first,
  rating: 5,
  comment: "Going out in public is really hard for me, but Olivia made the library visit feel safe. She didn't rush me or draw attention to my anxiety — she just stayed close and let me go at my own pace. Really grateful."
)

# Raj reviews James — both past appointments reviewed
raj_james_appts = Appointment.where(client: raj, support_worker: james)
                             .where('date < ?', Time.now).order(:date)

[
  { appt: raj_james_appts[0], rating: 4, comment: "James is easy to talk to and very reliable. The coffee catch-up was relaxed and he asked good questions about how things are going. Felt more like a conversation than a 'session'." },
  { appt: raj_james_appts[1], rating: 5, comment: "The goal-setting session was genuinely useful — James helped me break things down into steps I can actually follow. He listens well and doesn't make you feel judged for where you're at." },
].each do |r|
  Review.create!(client: raj, support_worker: james, appointment: r[:appt], rating: r[:rating], comment: r[:comment])
end

# Amina reviews Priya — 1 of 2 past appointments reviewed
amina_priya_appts = Appointment.where(client: amina, support_worker: priya)
                               .where('date < ?', Time.now).order(:date)

Review.create!(
  client: amina, support_worker: priya,
  appointment: amina_priya_appts.first,
  rating: 5,
  comment: "Priya clearly knows her stuff. She coordinated seamlessly with my physio and kept me motivated during a really difficult session. Having her there made a huge difference — I wouldn't have pushed through without the support."
)

puts "Reviews seeded: #{Review.count}"
