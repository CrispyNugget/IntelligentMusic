

'''
How it should be like in the beta version (Optimisation such as how many bars to generate each time is not done yet):

Check directory 
	##LATER make music directory in the same file (cd .) if it does not already exist
	find base in music (file name specified in parameters)
		##LATER if error print
		print base version
	find latest version and save to variable for READ to use
		print version
	make new version
		print making destination for new version...
LOOP FOR HOW MANY TIMES (TO GENERATE AUDIO 1-10 FOR READ
If track == new then, else 
Generate random OR Read (file info and rating IF ANY CAN BE NONE) (GENETICS???)
	generate random instrument
		generate instrument 1,2,3,4 etc. as specified in parameters 
			#high how many mid low.
		print instrument 1 frequencies, print instrument 2 frequencies, etc.
	generate random notes
		bar 1 [to x] (in parameters):
			instrument 1:
				how many notes to generate (length) 
					#generated by RNG, first how long then second; last will be to length for bar. So FOR x time less than a bar.
				
				the notes (might need to use for tensor flow and genetics)
			instrument 2, etc.:
	save to file called BASE which includes notes and instruments and NEW DIRECTORY
	print progress to screen

	FOR READ
		save to the directory of the version
		edit instrument
		edit notes
		save as 1, 2, 3, etc.
	
PROCESS note  (*CHANGE)
save and export
	called base, version 1,2 etc. for audio
	

Rate auto (tensor flow) (how many times)
	how much can I train AI to rate songs? Or how much do I want to allow in beta?
	#rate high mid low?? Rate entire song??? ALLOWED IN GENETICS??
Rate manual in another file
	rate overall 1-5
		#RATE EACH INSTRUMENT?? ALLOWED IN GENETICS??
Genetics (mutations)
	something here
		improve instrument
		improve notes


Publish beta and specify future directions, e.g. tensor flow.
'''
