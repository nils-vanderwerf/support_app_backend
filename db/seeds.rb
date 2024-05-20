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


puts "Australian clients seeded successfully!"


# Create more specializations
specializations = ['Child Care', 'Elderly Care', 'Disability Support', 'Mental Health Support', 'Rehabilitation Support', 'Community Support', 'Physical Therapy', 'Healthcare Support']

specialization_objects = specializations.map do |specialization_name|
  Specialization.find_or_create_by(name: specialization_name)
end

# Then create more support workers and assign the specializations to them
support_workers = [
  {
    first_name: 'Olivia', 
    last_name: 'Williams', 
    age: 30, 
    bio: 'Passionate about providing quality support to clients.', 
    experience: '7 years working with elderly and disabled clients.', 
    phone: '0400123456', 
    email: 'olivia.williams@example.com', 
    availability: 'Weekdays', 
    specializations: specialization_objects.select { |s| ['Elderly Care', 'Disability Support'].include?(s.name) }, 
    location: 'Sydney'
  },
  {
    first_name: 'James', 
    last_name: 'Smith', 
    age: 35, 
    bio: 'Experienced in mental health and rehabilitation support.', 
    experience: '5 years working in community support.', 
    phone: '0400234567', 
    email: 'james.smith@example.com', 
    availability: 'Weekends', 
    specializations: specialization_objects.select { |s| ['Mental Health Support', 'Rehabilitation Support', 'Community Support'].include?(s.name) }, 
    location: 'Melbourne'
  },
  # ... other support workers ...
]

support_workers.each do |support_worker|
  SupportWorker.create!(support_worker)
end

puts "Support workers and specializations seeded successfully!"