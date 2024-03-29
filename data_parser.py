import import_beh_data_JC04 as di
import numpy as np
import pylab as plt
import matplotlib.patches as mpatches
from scipy import stats
from itertools import zip_longest
import math
import matplotlib.cm as cm
from matplotlib.lines import Line2D
import pickle


experiment = di.Experiment('Reversal2/')
s_ids = experiment.subject_IDs
sessions = [experiment.get_sessions(subject_ID, 'all') for subject_ID in s_ids]

def to_string_list(x):
    out = []
    for el in x:
        out.append(str(el))
    return out

def parse_session_data(sessions, sname):
    for i,subj_sessions in enumerate(sessions):
        print(i)
        store_probas = subj_sessions[0].store_probas
        sess_obj = {}
        choices = []
        outcomes = []
        free_choice = []
        trial_types = []
        allowed_actions = []
        proba_chosen = []
        for sess in subj_sessions:
            td = sess.trial_data
            all_event_print = sess.events_and_print
            all_prints = [all_event_print[i].name for i in range(len(all_event_print)) if type(all_event_print[i].name) == list and 'T' in all_event_print[i].name[0]] #take only all the print lines appearing at the end of a trial
            trial_type = [all_prints[i][4].split(':')[1] for i in range(len(all_prints))] #all trial type, 'FC'
            couple = [all_prints[i][5].split(':')[1] for i in range(len(all_prints))] #all couple of choice
            proba_choosed = list(map(float, [all_prints[i][8].split(':')[1] for i in range(len(all_prints))])) #all proba choosed
            choices += list(to_string_list(td['choices']))
            outcomes += to_string_list(td['outcomes'])
            free_choice += to_string_list(td['free_choice'])
            trial_types += list(trial_type)
            allowed_actions += list(couple)
            proba_chosen += list(proba_choosed)
            
        sess_obj["store_probas"] = store_probas
        sess_obj["choices"] = choices
        sess_obj["outcomes"] = outcomes
        sess_obj["free_choice"] = free_choice
        sess_obj["trial_types"] = trial_types
        sess_obj["proba_chosen"] = proba_chosen
        sess_obj["allowed_actions"] = allowed_actions
        # this is so stupid
        with open(sname + "_" + str(i), 'wb') as handle:
            pickle.dump(sess_obj, handle)
        print("saved")
    return sess_obj
        

if __name__ == '__main__':
    sess_obj = parse_session_data(sessions, "reversal2_sess_obj")
    print("DONE")