# -*- coding: utf-8 -*-
"""
Created on Mon Oct  4 10:56:50 2021

@author: juanc
"""


import import_beh_data_JC04 as di
import numpy as np
import pylab as plt
import matplotlib.patches as mpatches
from scipy import stats
from itertools import zip_longest
import math
import matplotlib.cm as cm
from matplotlib.lines import Line2D

#session = di.Session('C:/Users/jccerpa/Documents/Oxford/Labo_Oxford/Experiments/JC04_ThreeChoice/Data/Behaviour/D3.5d-2021-10-03-130114.txt')

def fraction_good_3pokes(session):
    '''find all pairs in free trials and check if the highest probability has been selected'''
    
    all_event_print = session.events_and_print
    all_prints = [all_event_print[i].name for i in range(len(all_event_print)) if type(all_event_print[i].name) == list and 'T' in all_event_print[i].name[0]] #take only all the print lines appearing at the end of a trial
    trial_type = [all_prints[i][4].split(':')[1] for i in range(len(all_prints))] #all trial type, 'FC'
    couple = [all_prints[i][5].split(':')[1] for i in range(len(all_prints))] #all couple of choice
    proba_choosed = list(map(float, [all_prints[i][8].split(':')[1] for i in range(len(all_prints))])) #all proba choosed
    print(session.subject_ID, session.datetime_string)
    
    choices = session.trial_data['choices']  # 1 - left; 2-up; 3- right
    outcomes = session.trial_data['outcomes']  # 1 - rewarded;  0 - non-rewarded 
    free_choice_trials = session.trial_data['free_choice']  # 1 - free choice trial  # 0 - forced choice trial
    free_trial = np.where(free_choice_trials == 1)[0] #ids of free trials 
    print("choices: ", choices)
    print("outcomes: ", outcomes)
    
    free_proba_choosed = np.array([proba_choosed[x] for x in range(len(proba_choosed)) if x in free_trial]) 
    
    high_prob = []
    low_prob = []
    for i,x in enumerate(trial_type):
        if x == 'FC':
            high_prob.append(float(all_prints[i][6].split(':')[1]))
            low_prob.append(float(all_prints[i][7].split(':')[1])) 
    
    probas = []    
    store_probas = session.store_probas #retrieve the order of the probas, e.g [0.5, 1, 0.2] means left = 50%, up=100% and right=20%
    
    for i in range(len(store_probas)):
        probas.append(float(store_probas[i]))
    
    choice_100v50 = [] #to stock proba selected when 100vs50 is encountered
    choice_100v10 = []
    choice_50v10 = []
    
    ids_100v50 = [] #store trial ids, (not necessary )
    ids_100v10 = []
    ids_50v10 = []
    
    for i in range(len(free_trial)):
        if high_prob[i] == 1.0 and low_prob[i] == 0.5:
            ids_100v50.append(i)
            choice_100v50.append(free_proba_choosed[i])
        elif high_prob[i] == 1.0 and low_prob[i] == 0.2:
            ids_100v10.append(i)
            choice_100v10.append(free_proba_choosed[i])
        elif high_prob[i] == 0.5 and low_prob[i] == 0.2:
            ids_50v10.append(i)
            choice_50v10.append(free_proba_choosed[i])
    
    good_100v50 = 0
    for i, x in enumerate(choice_100v50):
        if x == 1: #if animals choosed proba 100% it is a good response
            good_100v50 += 1
    fraction_100v50 = good_100v50 / len(choice_100v50)
            
    good_100v10 = 0
    for i, x in enumerate(choice_100v10):
        if x == 1:
            good_100v10 += 1
    fraction_100v10 = good_100v10 / len(choice_100v10)
    
    good_50v10 = 0
    for i, x in enumerate(choice_50v10):
        if x == 0.5:
            good_50v10 += 1
    fraction_50v10 = good_50v10 / len(choice_50v10)
    
    return(fraction_100v50, fraction_100v10, fraction_50v10)


def average_correct_3pokes(experiment, subject_IDs='all', when='all'):
    print("experiment subject ids", experiment.subject_IDs)
    if subject_IDs == 'all':
        subject_IDs = sorted(experiment.subject_IDs)
    else:
        subject_IDs = sorted([experiment.subject_IDs[i] for i in range(len(experiment.subject_IDs)) if experiment.subject_IDs[i] in subject_IDs])
     
    print(subject_IDs)    
    #subject_IDs = sorted([experiment.subject_IDs[i] for i in range(len(experiment.subject_IDs)) if experiment.subject_IDs[i] in animals])
    subject_sessions = [experiment.get_sessions(subject_ID,when) for i, subject_ID in enumerate(subject_IDs)]
    print("subject sessionse", subject_sessions)
    fraction_individual = [[fraction_good_3pokes(session) for session in subject] for subject in subject_sessions]

    sessions_100v50 = [[] for i in range(len(fraction_individual))]
    sessions_100v20 = [[] for i in range(len(fraction_individual))]
    sessions_50v20 = [[] for i in range(len(fraction_individual))]    
    for i in range(len(fraction_individual)):
        for j in range(len(fraction_individual[i])):
            sessions_100v50[i].append(fraction_individual[i][j][0])
            sessions_100v20[i].append(fraction_individual[i][j][1])
            sessions_50v20[i].append(fraction_individual[i][j][2])
            
    # get the maximum length
    maxlen = len(max(sessions_100v50, key=len))
    # pad left of each sublist with NaN to make it as long as the longest
    for sublist in sessions_100v50:
        sublist[:] = sublist + [math.nan] * (maxlen - len(sublist))  

    # get the maximum length
    maxlen = len(max(sessions_100v20, key=len))
    # pad left of each sublist with NaN to make it as long as the longest
    for sublist in sessions_100v20:
        sublist[:] = sublist + [math.nan] * (maxlen - len(sublist))

    # get the maximum length
    maxlen = len(max(sessions_50v20, key=len))
    # pad left of each sublist with NaN to make it as long as the longest
    for sublist in sessions_50v20:
        sublist[:] = sublist + [math.nan] * (maxlen - len(sublist))
            
    print('sessions100v50', sessions_100v50)
    mean_100v50 = np.nanmean(sessions_100v50, axis=0)
    mean_100v20 = np.nanmean(sessions_100v20, axis=0)
    mean_50v20 = np.nanmean(sessions_50v20, axis=0)
    
    sub_ave_fraction = [np.mean(fraction_individual[i],axis = 0).tolist() for i, subject in enumerate(fraction_individual)] #average for each indiv
    sub_sem_fraction = [stats.sem(fraction_individual[i],axis = 0).tolist() for i, subject in enumerate(fraction_individual)]
    print(sub_ave_fraction)
    
    mean_fraction_group = np.nanmean(sub_ave_fraction,axis=0).tolist() #average across all subjects
    sem_fraction_group = stats.sem(sub_ave_fraction,axis=0)
    
    print(mean_fraction_group)
    
    sub = list(zip(*sub_ave_fraction)) #for scatter plot, need to group data of each indiv for the same x (=couple of probas)
    
    #print(sub)
    
    width = 1 
    fig = plt.figure(1)
    ax = fig.add_subplot(111)
    ax = plt.gca()
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    #rects = ax.bar(0, var_75v25[0], width, yerr=var_75v25[1], color=[0,0,0,0], edgecolor='k', linewidth = 2)
    rects1 = ax.bar(1, mean_fraction_group[0], width, yerr=sem_fraction_group[0], color=[0,0,0,0], edgecolor='k', linewidth = 2)  ##if individual data points use (color=[0,0,0,0], edgecolor ='k', linewidth = 1) for the bar to be transparent
    rects2 = ax.bar(2, mean_fraction_group[1], width, yerr=sem_fraction_group[1], color=[0,0,0,0], edgecolor='k', linewidth = 2)
    rects3 = ax.bar(3, mean_fraction_group[2], width, yerr=sem_fraction_group[2], color=[0,0,0,0], edgecolor='k', linewidth = 2)
    plt.axhline(0.5, color='lightcoral')
    xTickMarks = ['100v50', '100v20', '50v20']
    ax.set_xticks(range(1, 4))
    xtickNames = ax.set_xticklabels(xTickMarks)
    plt.ylim(0, 1)
    plt.ylabel('Fraction choice highest proba')
    
    num_animals = len(sub_ave_fraction)
    colors = cm.rainbow(np.linspace(0, 1, num_animals))
    
    x_pos = range(1, len(mean_fraction_group)+1)
    x_for_scatter = [np.ones(num_animals) * x_pos[i-1] for i in x_pos] #multiply each x positions by the number of animals to have the good size for scatter plot
    
    for i in range(len(sub)):
        scatter = ax.scatter(x_for_scatter[i], sub[i], c=colors, s=6)
   
    #manually create legend for colors
    #all_patch = []
    #for i in range(len(colors)):
    #    all_patch.append(mpatches.Patch(color=colors[i], label=subject_IDs[i]))
    #plt.legend(handles=all_patch, loc='right', bbox_to_anchor=(1.2,0.5), fontsize=8)
    
    #use Line2D instead of patch to customize markers as circle in the legend
    all_lines = []
    for i in range(len(colors)):
        all_lines.append(Line2D(range(1), range(1), color='white', marker='o', markerfacecolor=colors[i])) #creates a line with a circle in middle, line put as white so it is not visible
    plt.legend(all_lines,subject_IDs,numpoints=1, loc='right', bbox_to_anchor=(1.15,0.5), fontsize=7)
    
    for i in range(len(sub[0])):
        plt.plot([x_for_scatter[0][i], x_for_scatter[1][i], x_for_scatter[2][i]],[sub[0][i], sub[1][i], 
                 sub[2][i]],linewidth=0.5,color='k')     
        
    #for graph of evolution of the choices across sessions
    fig, (ax1, ax2, ax3) = plt.subplots(1, 3, sharey=True)
    #fig = plt.figure(2)
    x_ = range(1, len(sessions_100v50[0])+1)
    print(x_)
    #ax = fig.add_subplot(111)
    #ax = plt.gca()
    ax1.spines['top'].set_visible(False)
    ax1.spines['right'].set_visible(False)
    for i in range(len(sessions_100v50)):
        #ax1.plot(x_, sessions_100v50[i], color=colors[i], marker='o', markersize=1)
        ax1.plot(x_, sessions_100v50[i], color='silver', marker='o', markersize=1)
    ax1.plot(x_, mean_100v50, color='blue', marker='o')
    #ax1.axvline(x=3)    
    ax1.set_xticks(range(1, len(sessions_100v50[0])+1))
    ax1.set_title('100v50')
    ax2.spines['top'].set_visible(False)
    ax2.spines['right'].set_visible(False)
    for i in range(len(sessions_100v20)):
        #ax2.plot(x_, sessions_100v20[i], color=colors[i], marker='o') 
        ax2.plot(x_, sessions_100v20[i], color='silver', marker='o', markersize=1)
    ax2.plot(x_, mean_100v20, color='blue', marker='o')        
    #ax2.axvline(x=3) 
    ax2.set_xticks(range(1, len(sessions_100v20[0])+1))
    ax2.set_title('100v20')    
    ax3.spines['top'].set_visible(False)
    ax3.spines['right'].set_visible(False)
    for i in range(len(sessions_50v20)):
        #ax3.plot(x_, sessions_50v20[i], color=colors[i], marker='o')
        ax3.plot(x_, sessions_50v20[i], color='silver', marker='o', markersize=1)
    ax3.plot(x_, mean_50v20, color='blue', marker='o')        
    #ax3.axvline(x=3) 
    ax3.set_xticks(range(1, len(sessions_50v20[0])+1)) 
    ax3.set_title('50v20')    
    plt.ylim(0, 1.1)
    plt.show()

    
    #use Line2D instead of patch to customize markers as circle in the legend
    #all_lines = []
    #for i in range(len(colors)):
    #    all_lines.append(Line2D(range(1), range(1), color='white', marker='o', markerfacecolor=colors[i])) #creates a line with a circle in middle, line put as white so it is not visible
    #plt.legend(all_lines,subject_IDs,numpoints=1, loc='right', bbox_to_anchor=(1.5,0.5), fontsize=7)
    
#experiment = di.Experiment('C:/Users/jccerpa/Documents/Oxford/Labo_Oxford/Experiments/JC04_ThreeChoice_A2a_Drd1/Data/Photometry/Behaviour')  
#experiment = di.Experiment('C:/Users/Cerpa Juan Carlos/Documents/Labos/Labo Oxford/OneDrive/Labo_Oxford/Experiments/JC04_ThreeChoice_A2a_Drd1/Photometry/Behaviour')
experiment = di.Experiment('Initial/')

#retrain = ['2021-10-30', '2021-10-31']
#photo_days = ['2021-11-06', '2021-11-08', '2021-11-09', '2021-11-10', '2021-11-11', '2021-11-13', '2021-11-15', '2021-11-16']
#day_reversal = ['2021-11-18', '2021-11-19', '2021-11-21', '2021-11-22', '2021-11-23', '2021-11-24', '2021-11-25', '2021-11-26', '2021-11-27', '2021-11-28', '2021-11-29', '2021-11-30']
day_reversal = ['2021-12-07']
#animals_photo = ['D3.3b', 'D3.3d', 'D4.4b', 'D4.4g', 'D3.5b', 'D3.5d', 'A3.6a', 'A3.6b', 'A3.6d', 'A3.5a']
#animals_photo = ['D3.3d', 'A3.5a', 'D3.5b', 'D4.4b'] #bad 4 mice
animals_photo = ['A3.6b', 'A3.6d', 'D4.4b', 'D4.4c']
#animals_photo = ['D3.5d', 'A3.6a', 'A3.6b', 'A3.6d', 'A3.5a'] #2nd half 
#animals_photo = ['D3.3b', 'D3.3d', 'D4.4b', 'D4.4c', 'D4.4g', 'D3.5b'] #1st half
#animals_photo = ['A3.6d']
#days = ['2021-10-14']    

average_correct_3pokes(experiment, subject_IDs=animals_photo, when='all')
