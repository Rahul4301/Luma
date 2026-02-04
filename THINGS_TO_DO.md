# THINGS TO DO
- implmenent "Study mode"
    - study mode will help users stay locked in for a set time : users will set
    - ml model using camera will determine if user is not sudying
    - binary image classifier using cnn
    - system aggregates user attention every 3-5 seconds
    - keeps going until timer ends

- bundle app with ollama cloud
- bundle app with fine tuned llm to run on their local machine, MUST be small - around 6-7B 

- make tabs rearrangeable
- make ai panel ui better(tbd)

- ai panel functionality MUST:
    - be able to open tabs through chat
    - be able to delete tabs through chat
    - be able to access information from other tabs(user must select to add in context)
    - be able to accept input files into tab chat
        - in tab chat the contents of the tab is considered the knowledge base in the ai instance - should be able to add more documents and stuff
        
- add history for chats - must be able to go back and see
    - web page has its own id and all chats in session are tied to the id
    - if 100 chats are done in a single page, it will store in history as a single session
    - all chats will be tied to session until website is not active/closed