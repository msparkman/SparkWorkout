require 'mongo'

include Mongo

# A class for interacting with the SparkWorkout mongodb
class SparkWorkoutDatabase
	@@database_url = "mongodb://msparkman:msparkman@ds039960.mongolab.com:39960/sparkworkout"
	@@database_port = 39960

	# Inserts a routine document
	def insert_routine(date, type, name)
		mongo_client = MongoClient.from_uri(@@database_url)
		database = mongo_client.db("sparkworkout")
		routines_collection = database["routines"]
		
		routine_document = {"date" => date,
			"type" => type,
			"name" => name}
			
		return routines_collection.insert(routine_document)
	end
	
	# Inserts an exercise document
	def insert_exercise_set(routine_id, type, name, number_of_reps, weight, comment)
		mongo_client = MongoClient.from_uri(@@database_url)
		database = mongo_client.db("sparkworkout")
		exercise_collection = database[type + "_" + name]
		
		exercise_document = {"routine_id" => routine_id,		
			"num_reps" => number_of_reps, 
			"weight" => weight,
			"comment" => comment}
			
		exercise_collection.insert(exercise_document)
	end
	
	# Retrieves the most recent exercise routine for a given exercise
	def get_last_routine(type, name)
		mongo_client = MongoClient.from_uri(@@database_url)
		database = mongo_client.db("sparkworkout")

		# If no type or name were provided, retrieve the last routine entered
		if type.nil? or type.empty? or name.nil? or name.empty?
			last_routine_document = database["routines"].find().sort("_id" => -1).limit(1).first()
			# If no routine is found, return
			if last_routine_document.nil? or last_routine_document.empty?
				return nil
			end

			type = last_routine_document["type"]
			name = last_routine_document["name"]
		else
			# Get the highest routine ID from the routines collection for that type and name
			last_routine_document = 
				database["routines"].find("type" => type, "name" => name).sort("_id" => -1).limit(1).first()
		end

		exercise_result_array = {}

		# Retrieve all records from the collection that have that routine ID and sort in ascending order
		exercise_collection = database[type + "_" + name]

		# Return the empty array since no routine or collection as found for that type and name
		if last_routine_document.nil? or exercise_collection.nil?
			return exercise_result_array
		end

		exercise_result_cursor = exercise_collection.find("routine_id" => last_routine_document["_id"]).sort("_id" => 1)

		# Loop through each document to populate the array being returned
		exercise_result_cursor.each do |row| 
			id = row.delete("_id"); 
			exercise_result_array["#{id}"] = row 
		end

		# Add in the type and name
		exercise_result_array["type"] = type
		exercise_result_array["name"] = name
		
		return exercise_result_array
	end

	# Retrieves the most recent exercise routine for a given exercise
	def get_all_routines()
		mongo_client = MongoClient.from_uri(@@database_url)
		database = mongo_client.db("sparkworkout")

		# Grab all the unique routine types so we can grab all their respective routine names
		routine_types = database["routines"].distinct("type")

		all_routines_array = Array.new

		# Loop through the types
		routine_types.each do |type|
			# Grab all the distinct names for each type
			name_documents = database.command({
				"distinct" => "routines",
				"query" => {
					"type"=> type
				},
				"key" => "name"
			});

			# Loop through each name document to grab the unique name values
			name_documents["values"].each do |name|
				# Retrieve all records from the collection that have that routine ID and sort in ascending order
				exercise_collection = database[type + "_" + name]

				# Skip to the next name if this collection doesn't exist
				if exercise_collection.nil? or exercise_collection.size() < 1
					next
				end

				# Grab all the exercises from this collection
				exercise_result_cursor = exercise_collection.find().sort("_id" => 1)

				exercise_result_array = {}

				# Loop through each document to populate the array being returned
				exercise_result_cursor.each do |row| 
					id = row.delete("_id"); 
					exercise_result_array["#{id}"] = row 
				end

				# Add in the type and name
				exercise_result_array["type"] = type
				exercise_result_array["name"] = name

				all_routines_array.push(exercise_result_array)
			end
		end

		return all_routines_array
	end
end
