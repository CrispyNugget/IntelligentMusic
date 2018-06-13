from export import *
from plot import *
from instruments import *
from evaluate import *
from scales import *
from generate import *
import time

#randomInstrument()
#quit()

print ""

####Execution time####
start_time = time.time()
####Execution time####

##Make note import into array later and change Generate note to accept array only; use *argv or something


#newInstrument()
#instrument1() #Change later to GenerateInstrument(number of instruments)
#addInstrumentToSong()

#instrument2()

#randomNotes()


#GenerateNote(64, 1567.98)
#GenerateNote(16,note("80"))
#addInstrumentToSong()

#GenerateNote([[note("C4"),"sine",0,1]],[[32, [note("C4")]]])
GenerateNote(instrumentC,[[32, [note("rest")]],[32, [note("C4")]],[32, [note("C5")]]])
export()


####Execution time####
print "My program took", time.time() - start_time, "seconds to run (Excluding plotting time)"
####Execution time####

plot()


print ""

'''
	When you try to divide a list by a real number, python says "you are crazy! You can't do that." The array is like a vector. If you divide it by a real number, each "thing" in there is divided by that number. This can be super useful.
'''

'''
t = arange(0,3,0.01) - this makes an array of values. The values start at 0, end at 3 and increment by 0.01.

x = cos(pi*t*F) - here is the cool part. Remember that t is an array. This means that x is also an array. I don't have to do any loops or anything like that. Boom, just does it.
'''

'''
Do Fourier transform on piano later
'''

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
{
If track == new then
Generate random ELSE FOR READ (file info and rating IF ANY CAN BE NONE) (GENETICS???)
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
}
	
PROCESS note  (*CHANGE)
export
	in generate instrument there will be different frequencies. Base is c4. so. Particular waveform and frequency times Current freq divided by c4.
	in process every waveform will be added to local data like the current one.
save called base, version 1,2 etc. for audio
	

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


###Change song variable to "barData" next time, and in Process, everytime run clear data (put in start of process def)
'''
