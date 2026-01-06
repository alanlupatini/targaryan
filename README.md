
# Ravenclaw Gaming Investment Group

## Team Members:
Alan Lupatini
António Galvão
Carmelina MBesso
Rui Parreira 

## Project Overview
We are a newly employed data analyst in the Customer Experience (CX) team at Vanguard, the US-based investment management company. You've been thrown straight into the deep end with your first task. Before your arrival, the team launched an exciting digital experiment, and now, they're eagerly waiting to uncover the results and need your help!

An A/B test was set into motion from 3/15/2017 to 6/20/2017 by the team.

Control Group: Clients interacted with Vanguard's traditional online process.
Test Group: Clients experienced the new, spruced-up digital interface.
Both groups navigated through an identical process sequence: an initial page, three subsequent steps, and finally, a confirmation page signaling process completion.
The goal is to see if the new design leads to a better user experience and higher process completion rates

- **Objective:** 
The digital world is evolving, and so are Vanguard’s clients. Vanguard believed that a more intuitive and modern User Interface (UI), coupled with timely in-context prompts (cues, messages, hints, or instructions provided to users directly within the context of their current task or action), could make the online process smoother for clients. The critical question was: Would these changes encourage more clients to complete the process?.  

- **Dataset:** 

Client Profiles (df_final_demo): Demographics like age, gender, and account details of our clients.
Digital Footprints (df_final_web_data): A detailed trace of client interactions online, divided into two parts: pt_1 and pt_2. 
Experiment Roster (df_final_experiment_clients): A list revealing which clients were part of the grand experiment.

**Dataset Features:**
First dataset (df_final_experiment_clients) is composed: client_id and variation - We can see if clientes are on Test or Control. 
Second dataset (df_final_web_data) is composed: client_id, visitor_id, process_step and date/time. 
Third dataset (f_final_de) is composed by the demographics: cliend_id, clnt_tenure_yr, clnt_tenure_mhth, clnt_age, genrd, num:accts, bal, calls_6_mnth, logons_6_mnth


## Final project presentation
The results from the analysis can be found in the presentation slides of the project:
XXXXXXXXXXXXXXXXXXXXXX

## Tools & Libraries
- Python 3  
- Pandas (data manipulation)  
- NumPy (numerical operations)  
- Matplotlib, Seaborn (visualization)  
- Trello (project management)  
- GitHub (collaboration)
- MySQL (data manipulation)
- DrawnBD (Visualization)

## Day 1/2 - Project Initiation & Data Cleaning
Os Day 1 and 2, the team created the enviroment, repository, Trelo board. 
Team merged and cleanead databasets for exploration. 
We analised columns, and decided to keep ages in float, unknown in genre, etc.  

### 1. Created a Kanban Board for Project Management Purposes on Trello.
We organized the tasks for the whole project. 
https://trello.com/b/q2e3vDqd/mon-tableau-trello

### 2. Created a Github Repository for the Project:
https://github.com/alanlupatini/targaryan/tree/main
We created the repository and defined the collaboration status for all group members. We use branch and merge techniques, so all files are always updated. We have practiced working collaboratively on the repository.


## Objectives:
Trying to ask the qestions: 
Who are the primary clients using this online process?
Are the primary clients younger or older, new or long-standing?
Carried out a client behaviour analysis to answer any additional relevant questions you think are important.

Explore datasets (EDA)
We draw ERD diagram for the datacharts:
https://www.drawdb.app/editor?shareId=ab97aa8aec0f25c0ad4d3e7055352ad2

Open datasets in Python
Check shape & columns
Check missing values
Check duplicates
Save observations in notebook


## Day 3 - 
## Objectives:
Use at least completion rate, time spent on each step and error rates. Add any KPIs you might find relevant.
Completion Rate: The proportion of users who reach the final 'confirm' step.
Time Spent on Each Step: The average duration users spend on each step.
Error Rates: If there's a step where users go back to a previous step, it may indicate confusion or an error. You should consider moving from a later step to an earlier one as an error.
Anwser this: Based on the chosen KPIs, how does the new design's performance compare to the old one?


## Day 4/5 -
## Objectives:
Conduct hypothesis testing to make data-driven conclusions about the effectiveness of the redesign



## Day 6 -

## Day 7 - 

## Day 8 - 

## Day 9 - 

## Day 10 - Presentation 




### 1. Data Transformation

### 2. Analysis & Conclusions

### 3. Challenges in the Project









































# Project overview
...

# Installation

1. **Clone the repository**:

```bash
git clone https://github.com/YourUsername/repository_name.git
```

2. **Install UV**

If you're a MacOS/Linux user type:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

If you're a Windows user open an Anaconda Powershell Prompt and type :

```bash
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

3. **Create an environment**

```bash
uv venv 
```

3. **Activate the environment**

If you're a MacOS/Linux user type (if you're using a bash shell):

```bash
source ./venv/bin/activate
```

If you're a MacOS/Linux user type (if you're using a csh/tcsh shell):

```bash
source ./venv/bin/activate.csh
```

If you're a Windows user type:

```bash
.\venv\Scripts\activate
```

4. **Install dependencies**:

```bash
uv pip install -r requirements.txt
```

# Questions 
...

# Dataset 
...

## Main dataset issues

- ...
- ...
- ...

## Solutions for the dataset issues
...

# Conclussions
...

# Next steps
...
