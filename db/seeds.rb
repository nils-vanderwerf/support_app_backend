# db/seeds.rb

# Clear existing data to prevent duplication if re-seeding
Client.delete_all
SupportWorker.delete_all

# Create several clients with more unique and varied names and Australian phone numbers
clients = [
  { name: "Elena Martinez", age: 34, gender: "Female", address: "2019 Maple Avenue", phone: "0421 210 909", health_conditions: "Hypertension", medication: "Lisinopril", allergies: "Ibuprofen", emergency_contact_name: "Miguel Martinez", emergency_contact_phone: "0431 167 474" },
  { name: "Raj Patel", age: 29, gender: "Male", address: "452 Cedar Lane", phone: "0422 289 191", health_conditions: "None", medication: "None", allergies: "Shellfish", emergency_contact_name: "Anita Patel", emergency_contact_phone: "0423 324 141" },
  { name: "Amina Ali", age: 52, gender: "Female", address: "783 Spruce Street", phone: "0424 986 262", health_conditions: "Diabetes", medication: "Metformin", allergies: "Latex", emergency_contact_name: "Yusuf Ali", emergency_contact_phone: "0425 542 929" },
  { name: "Tomás Rivera", age: 43, gender: "Male", address: "88 Pine Road", phone: "0426 453 232", health_conditions: "Asthma", medication: "Ventolin", allergies: "Penicillin", emergency_contact_name: "Lucía Rivera", emergency_contact_phone: "0427 634 848" },
  { name: "Mai Nguyen", age: 38, gender: "Female", address: "325 Elm Street", phone: "0428 748 282", health_conditions: "Epilepsy", medication: "Levetiracetam", allergies: "Nuts", emergency_contact_name: "Duy Nguyen", emergency_contact_phone: "0429 869 494" }
]

clients.each do |client|
  Client.create!(client)
end

SupportWorker.create([
  {
    first_name: 'Olivia', 
    last_name: 'Williams', 
    age: 30, 
    bio: 'Passionate about providing quality support to clients.', 
    experience: '7 years working with elderly and disabled clients.', 
    phone: '0400123456', 
    email: 'olivia.williams@example.com', 
    availability: 'Weekdays', 
    specializations: 'Elderly care, disability support', 
    location: 'Sydney'
  },
  {
    first_name: 'Liam', 
    last_name: 'Brown', 
    age: 45, 
    bio: 'Dedicated support worker with extensive experience.', 
    experience: '20 years in mental health support.', 
    phone: '0412345678', 
    email: 'liam.brown@example.com', 
    availability: 'Weekends', 
    specializations: 'Mental health support', 
    location: 'Melbourne'
  },
  {
    first_name: 'Emma', 
    last_name: 'Taylor', 
    age: 28, 
    bio: 'Empathetic and skilled support worker.', 
    experience: '5 years in community support.', 
    phone: '0423456789', 
    email: 'emma.taylor@example.com', 
    availability: 'Weekdays', 
    specializations: 'Community support, disability support', 
    location: 'Brisbane'
  },
  {
    first_name: 'Noah', 
    last_name: 'Davis', 
    age: 35, 
    bio: 'Focused on delivering personalized support services.', 
    experience: '10 years in elderly care.', 
    phone: '0434567890', 
    email: 'noah.davis@example.com', 
    availability: 'Evenings', 
    specializations: 'Elderly care, physical therapy', 
    location: 'Perth'
  },
  {
    first_name: 'Ava', 
    last_name: 'Clark', 
    age: 40, 
    bio: 'Experienced in providing comprehensive support.', 
    experience: '15 years in healthcare support.', 
    phone: '0445678901', 
    email: 'ava.clark@example.com', 
    availability: 'Weekdays', 
    specializations: 'Healthcare support, disability support', 
    location: 'Adelaide'
  },
  {
    first_name: 'Mason', 
    last_name: 'Martinez', 
    age: 32, 
    bio: 'Committed to enhancing the well-being of clients.', 
    experience: '8 years in mental health and community support.', 
    phone: '0456789012', 
    email: 'mason.martinez@example.com', 
    availability: 'Weekends', 
    specializations: 'Mental health support, community support', 
    location: 'Hobart'
  },
  {
    first_name: 'Sophia', 
    last_name: 'Walker', 
    age: 37, 
    bio: 'Professional support worker with a compassionate approach.', 
    experience: '12 years in elderly and palliative care.', 
    phone: '0467890123', 
    email: 'sophia.walker@example.com', 
    availability: 'Evenings', 
    specializations: 'Elderly care, palliative care', 
    location: 'Canberra'
  },
  {
    first_name: 'Ethan', 
    last_name: 'King', 
    age: 29, 
    bio: 'Support worker dedicated to improving client outcomes.', 
    experience: '6 years in disability support and healthcare.', 
    phone: '0478901234', 
    email: 'ethan.king@example.com', 
    availability: 'Weekdays', 
    specializations: 'Disability support, healthcare support', 
    location: 'Darwin'
  }
])

puts "Australian clients seeded successfully!"