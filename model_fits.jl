using CSV
using DataFrames
using Optim
using Plots
using Distributions
using Pickle
using StatPlots

### utility functions for the model and model comparison ###

function softmax(beta, xs)
    return exp.(beta * xs) ./ sum(exp.(beta * xs))
end

function sigmoid(x)
    #return exp.(x) / (1 + exp.(x))
    return 1 / (1 + exp.(-x))
end


function squeeze(x)
    x = reshape(x, size(x)[2:end])
    return x
end

Bayes_Factor(ll1, ll2) = exp(ll2 - ll1)
Bayes_Factor_AIC(ll1,ll2,n1,n2) = exp((ll2 - n2) - (ll1 - n1))
Bayes_Factor_BIC(ll1,ll2,n1,n2,m1,m2) = exp((ll2 - ((n2/2) * log(m2))) - (ll1 - ((n1/2)*log(m1))))

function likelihood_ratio_test(ll1,ll2,n)
    # compute ratio
    d = 2 * abs((ll2 - ll1))
    # get chi^2 distribution
    chisq = Distributions.Chisq(n)
    #cdf
    cdf_p = Distributions.cdf(chisq,d)
    p_value = 1 - cdf_p
    return d, p_value
end

function multimin_params(f, inputs, params,  N_runs = 20,return_full_list=false)
    # range them all parameters over uniform value from 0,1 as initialization
    param_output_list = []
    LL_list = []
    for i in 1:N_runs
        init_params = rand(3) .* 1 # uniform between 0-> 2 --
        output_params, output_LL = optimize_mouse_general(f,inputs, params)
        if !isnan(output_LL)
            push!(param_output_list, output_params)
            push!(LL_list, output_LL)
        else
            print("NAN occured in optimization! \n")
        end
    end
    # find minimum
    min_idx = findmin(LL_list)[2]
    if return_full_list
        return param_output_list[min_idx], LL_list[min_idx], param_output_list, LL_list, min_idx
    else
        return param_output_list[min_idx], LL_list[min_idx]
    end
end

function likelihood_ratio_comparison(ll_f1, ll_f2, inputs, n1,n2,return_params=true)
    n_additional = abs(n2 - n1)
    params1, LL_1 = multimin_params(ll_f1, inputs, n1)#optimize_mouse_general(ll_f1, inputs,n1)
    params2,LL_2 = multimin_params(ll_f2, inputs, n2)#optimize_mouse_general(ll_f2, inputs, n2)
    d, p_value = likelihood_ratio_test(LL_1, LL_2,n_additional)
    if return_params
        return d,p_value, LL_1, LL_2, params1, params2
    end
    return d, p_value, LL_1, LL_2
end

function optimize_mouse_general(ll_func, input_list, n_params)
    init_params = rand(n_params) 
    opt = optimize(init_params -> ll_func(input_list...,init_params...,false), init_params)
    output_params = Optim.minimizer(opt)
    LL = Optim.minimum(opt)
    return output_params,LL
end

function parse_allowed_actions_to_idx(allow)
    if allow == "U-R"
        return 1
    end
    if allow == "L-U"
        return 3
    end
    if allow == "L-R"
        return 2
    end
end

### load session data ###

session_data = Pickle.load(open("Data_JC04/reversal1_sess_obj_1"))
session_data_initial = Pickle.load(open("Data_JC04/sess_obj_1"))
rewards_initial = parse.(Int,session_data_initial["outcomes"])
vcat(rewards_initial, rewards)
rewards = parse.(Int, session_data["outcomes"])
choices = parse.(Int, session_data["choices"])
free_choices = session_data["free_choice"]
free_choices_initial = session_data_initial["free_choice"]
vcat(free_choices_initial, free_choices)
allowed_actions = session_data["allowed_actions"]

# print some session data
session_data["store_probas"]
parse.(Float64,session_data["choices"])
session_data["trial_types"]
session_data["choices"]
session_data["allowed_actions"]



### Q learning functions for model fitting ###

NEGATIVE_Q_VAL = -100000.0


function Q_learner_ll(rs,choices,free_choices,allowed_actions , est_alpha, est_beta, visualize_Qs = false, record_N_correct = false)
    N_runs = length(choices)
    Qs = [0.0, 0.0,0.0]
    Qss = zeros(N_runs, length(Qs))
    LL = 0
    N_correct = 0
    free_choice_runs = 0
    for i in 1:N_runs
        # run forward model
        r = rs[i]
        choice_idx = Int(choices[i])
        #println("choice idx $choice_idx")
        if free_choices[i] == "True"
            allow_idx = parse_allowed_actions_to_idx(allowed_actions[i])
            Q_tilde = deepcopy(Qs)
            Q_tilde[allow_idx] = NEGATIVE_Q_VAL
            as = softmax(est_beta, Q_tilde)
        else
            as = zeros(length(Qs))
            as[choice_idx] = 1
        end

        delta = r - Qs[choice_idx]
        Qs[choice_idx] += est_alpha * delta
        # compute LL
        if free_choices[i] == "True"
            free_choice_runs +=1
            LL -= log(as[choice_idx])
            #println(record_N_correct)
            if record_N_correct == true
                println(argmax(as), choice_idx)

                if argmax(as) == choice_idx
                    N_correct +=1
                end
            end
        end
        if visualize_Qs
            Qss[i,:] = deepcopy(Qs)
        end
    end
    if record_N_correct
        return N_correct / free_choice_runs
    end
    if visualize_Qs
        return LL, Qss
    else
        return LL
    end
end


function Q_learner_decay_ll(rs,choices,free_choices,allowed_actions , est_alpha, est_beta,decay_coeff, visualize_Qs = false, record_N_correct = false)
    N_runs = length(choices)
    Qs = [0.0, 0.0,0.0]
    Qss = zeros(N_runs, length(Qs))
    LL = 0
    if record_N_correct
        N_correct = 0
    end
    for i in 1:N_runs
        # run forward model
        r = rs[i]
        choice_idx = Int(choices[i])
        #println("choice idx $choice_idx")
        if free_choices[i] == "True"
            allow_idx = parse_allowed_actions_to_idx(allowed_actions[i])
            Q_tilde = deepcopy(Qs)
            Q_tilde[allow_idx] = NEGATIVE_Q_VAL
            as = softmax(est_beta, Q_tilde)
        else
            as = zeros(length(Qs))
            as[choice_idx] = 1
        end

        delta = r - Qs[choice_idx]
        Qs[choice_idx] += (est_alpha * delta) - (decay_coeff * Qs[choice_idx])
        # compute LL
        if free_choices[i] == "True"
            LL -= log(as[choice_idx])
            if record_N_correct
                if argmax(as) == choice_idx
                    N_correct +=1
                end
            end
        end
        if visualize_Qs
            Qss[i,:] = deepcopy(Qs)
        end
    end
    if record_N_correct
        return N_correct / N_runs
    end
    if visualize_Qs
        return LL, Qss
    else
        return LL
    end
end

function Q_learner_force_free_learning_rate_ll(rs,choices,free_choices,allowed_actions , est_alpha_free, est_alpha_force, est_beta, visualize_Qs = false,record_N_correct = false)
    N_runs = length(choices)
    Qs = [0.0, 0.0,0.0]
    Qss = zeros(N_runs, length(Qs))
    LL = 0
    N_correct = 0
    free_choice_runs = 0
    for i in 1:N_runs
        # run forward model
        r = rs[i]
        choice_idx = Int(choices[i])
        #println("choice idx $choice_idx")
        if free_choices[i] == "True"
            allow_idx = parse_allowed_actions_to_idx(allowed_actions[i])
            Q_tilde = deepcopy(Qs)
            Q_tilde[allow_idx] = NEGATIVE_Q_VAL
            as = softmax(est_beta, Q_tilde)
        else
            as = zeros(length(Qs))
            as[choice_idx] = 1
        end

        delta = r - Qs[choice_idx]
        if free_choices[i] == "True"
            Qs[choice_idx] += est_alpha_free * delta
        end
        if free_choices[i] == "False"
            Qs[choice_idx] += est_alpha_force * delta
        end
        # compute LL
        if free_choices[i] == "True"
            free_choice_runs +=1
            LL -= log(as[choice_idx])
            if record_N_correct
                if argmax(as) == choice_idx
                    N_correct +=1
                end
            end
        end
        if visualize_Qs
            Qss[i,:] = deepcopy(Qs)
        end
    end
    if record_N_correct
        return N_correct / free_choice_runs
    end
    if visualize_Qs
        return LL, Qss
    else
        return LL
    end
end


function Q_learner_port_bias_ll(rs,choices,free_choices,allowed_actions , est_alpha, est_beta,left_bias, up_bias, right_bias, visualize_Qs = false)
    N_runs = length(choices)
    Qs = [0.0, 0.0,0.0]
    Qss = zeros(N_runs, length(Qs))
    LL = 0
    bias = zeros(3)
    bias[1] = left_bias
    bias[2] = up_bias
    bias[3] = right_bias
    for i in 1:N_runs
        # run forward model
        r = rs[i]
        choice_idx = Int(choices[i])
        #println("choice idx $choice_idx")
        if free_choices[i] == "True"
            allow_idx = parse_allowed_actions_to_idx(allowed_actions[i])
            Q_tilde = deepcopy(Qs)
            Q_tilde[allow_idx] = NEGATIVE_Q_VAL
            as = softmax(est_beta, Q_tilde)
        else
            as = zeros(length(Qs))
            as[choice_idx] = 1
        end

        delta = r - Qs[choice_idx]
        Qs[choice_idx] += est_alpha * delta
        # compute LL
        if free_choices[i] == "True"
            LL -= log(as[choice_idx])
        end
        if visualize_Qs
            Qss[i,:] = deepcopy(Qs)
        end
    end
    if visualize_Qs
        return LL, Qss
    else
        return LL
    end
end


function Q_learner_stickiness_bias_ll(rs,choices,free_choices,allowed_actions , est_alpha, est_beta,stick_bias, visualize_Qs = false, record_N_correct = false)
    N_runs = length(choices)
    Qs = [0.0, 0.0,0.0]
    Qss = zeros(N_runs, length(Qs))
    LL = 0
    N_correct = 0
    free_choice_runs = 0
    for i in 1:N_runs
        # run forward model
        r = rs[i]
        choice_idx = Int(choices[i])
        #println("choice idx $choice_idx")
        if free_choices[i] == "True"
            allow_idx = parse_allowed_actions_to_idx(allowed_actions[i])
            Q_tilde = deepcopy(Qs)
            Q_tilde[allow_idx] = NEGATIVE_Q_VAL
            Q_tilde[Int(choices[i-1])] += stick_bias
            as = softmax(est_beta, Q_tilde)
        else
            as = zeros(length(Qs))
            as[choice_idx] = 1
        end

        delta = r - Qs[choice_idx]
        Qs[choice_idx] += est_alpha * delta
        # compute LL
        if free_choices[i] == "True"
            free_choice_runs +=1
            LL -= log(as[choice_idx])
            if record_N_correct
                if argmax(as) == choice_idx
                    N_correct +=1
                end
            end
        end
        if visualize_Qs
            Qss[i,:] = deepcopy(Qs)
        end
    end
    if record_N_correct
        return N_correct / free_choice_runs
    end
    if visualize_Qs
        return LL, Qss
    else
        return LL
    end
end


function Q_learner_reward_lr(rs,choices,free_choices,allowed_actions , reward_lr, no_reward_lr, est_beta, visualize_Qs = false, record_N_correct = false)
    N_runs = length(choices)
    Qs = [0.0, 0.0,0.0]
    Qss = zeros(N_runs, length(Qs))
    LL = 0
    N_correct = 0
    free_choice_runs = 0
    for i in 1:N_runs
        # run forward model
        r = rs[i]
        choice_idx = Int(choices[i])
        #println("choice idx $choice_idx")
        if free_choices[i] == "True"
            allow_idx = parse_allowed_actions_to_idx(allowed_actions[i])
            Q_tilde = deepcopy(Qs)
            Q_tilde[allow_idx] = NEGATIVE_Q_VAL
            as = softmax(est_beta, Q_tilde)
        else
            as = zeros(length(Qs))
            as[choice_idx] = 1
        end
        if r > 0
            delta = r - Qs[choice_idx]
            Qs[choice_idx] += reward_lr * delta
        else
            delta = r - Qs[choice_idx]
            Qs[choice_idx] += no_reward_lr * delta
        end
        # compute LL
        if free_choices[i] == "True"
            free_choice_runs +=1
            LL -= log(as[choice_idx])
            #println(record_N_correct)
            if record_N_correct == true
                println(argmax(as), choice_idx)

                if argmax(as) == choice_idx
                    N_correct +=1
                end
            end
        end
        if visualize_Qs
            Qss[i,:] = deepcopy(Qs)
        end
    end
    if record_N_correct
        return N_correct / free_choice_runs
    end
    if visualize_Qs
        return LL, Qss
    else
        return LL
    end
end

function Q_learner_habit_model(rs,choices,free_choices,allowed_actions , Q_lr, habit_lr, Q_beta, habit_beta, visualize_Qs = false, record_N_correct = false)
    N_runs = length(choices)
    Qs = [0.0, 0.0,0.0]
    Hs = [0.0, 0.0,0.0]
    Qss = zeros(N_runs, length(Qs))
    Hss = zeros(N_runs, length(Hs))
    LL = 0
    N_correct = 0
    free_choice_runs = 0
    for i in 1:N_runs
        # run forward model
        r = rs[i]
        choice_idx = Int(choices[i])
        #println("choice idx $choice_idx")
        if free_choices[i] == "True"
            allow_idx = parse_allowed_actions_to_idx(allowed_actions[i])
            Q_tilde = deepcopy(Qs)
            Q_tilde[allow_idx] = NEGATIVE_Q_VAL
            as = softmax(1, Q_beta * Q_tilde + habit_beta * Hs)
        else
            as = zeros(length(Qs))
            as[choice_idx] = 1
        end

        delta = r - Qs[choice_idx]
        Qs[choice_idx] += Q_lr * delta
        action_vec = zeros(3)
        action_vec[choice_idx] = 1
        Hs += habit_lr * (action_vec - Hs)
        # compute LL
        if free_choices[i] == "True"
            free_choice_runs +=1
            LL -= log(as[choice_idx])
            #println(record_N_correct)
            if record_N_correct == true
                println(argmax(as), choice_idx)

                if argmax(as) == choice_idx
                    N_correct +=1
                end
            end
        end
        if visualize_Qs
            Qss[i,:] = deepcopy(Qs)
            Hss[i,:] = deepcopy(Hs)
        end
    end
    if record_N_correct
        return N_correct / free_choice_runs
    end
    if visualize_Qs
        return LL, Qss, Hss
    else
        return LL
    end
end

###### John Mikhael Model for fitting ####

function UCB_choose(G,N,a,b,c)
    c_param = c * sqrt(pi / 2)
    choice_probs = my_softmax((a + c_param)* G .- (b - c_param) * N) # Eq 6
    samp = findmax(rand(Multinomial(1, choice_probs)))[2] # get the actual index from the sampling
    return samp
end

function choose(G,N,a,b)
    choice_probs = my_softmax(a * G .- b * N) # Eq 6
    #choice_probs = [0.25,0.25,0.25,0.25]
    samp = findmax(rand(Multinomial(1, choice_probs)))[2] # get the actual index from the sampling
    return samp
end

function ACU_update(G,N,V,a,b,alpha,beta,r_samps, i)
    samp_idx = choose(G,N,a,b) # softmax choice
    r = r_samps[samp_idx, i] # get reward index
    # setup learning rates only when that action is chosen
    lr = zeros(length(G))
    lr[samp_idx] = alpha
    decay_factor = zeros(length(G))
    decay_factor[samp_idx] = beta
    # main updates
    G = G .+ (lr .* max.((r .- V),0)) .- (decay_factor .* G) # Eq27
    N = N .+ (lr .* max.(-(r .- V),0)) .- (decay_factor .* N) # Eq 28
    V = V .+ (alpha * (r .- V)) # Eq 2
    return G,N,V,samp_idx,r
end

function AU_update(G,N,V,a,b,alpha,beta,r_samps, i)
    samp_idx = choose(G,N,a,b) # softmax choice
    r = r_samps[samp_idx, i] # get reward index
    # setup learning rates only when that action is chosen
    lr = zeros(length(G))
    lr[samp_idx] = alpha
    decay_factor = zeros(length(G))
    decay_factor[samp_idx] = beta
    # main updates
    V = G .- N
    G = G .+ (lr .* max.((r .- V),0)) .- (decay_factor .* G) # Eq27
    N = N .+ (lr .* max.(-(r .- V),0)) .- (decay_factor .* N) # Eq 28
    #V = V .+ (alpha * (r .- V)) # Eq 2
    return G,N,V,samp_idx,r
end

function AU_model_LL(rs,choices,free_choices,allowed_actions, alpha, beta, a,b, softmax_beta, record_N_correct = false, use_critic = true)
    V = zeros(1)
    G = zeros(3) #.+ 0.0
    N = zeros(3) #.+ 1.0
    N_runs = length(choices)
    LL = 0
    N_correct = 0
    free_choice_runs = 0
    a =  1
    b = 1
    for i in 1:N_runs
        r = rs[i]
        choice_idx = Int(choices[i])
        #println("choice idx $choice_idx")
        if free_choices[i] == "True"
            allow_idx = parse_allowed_actions_to_idx(allowed_actions[i])
            if use_critic
                G = G .+ (alpha .* max.((r .- V),0)) .- (beta .* G) # Eq27
                N = N .+ (alpha .* max.(-(r .- V),0)) .- (beta .* N) # Eq 28
                V = V .+ (alpha * (r .- V)) # Eq 2
            else
                V = G .- N
                G = G .+ (alpha .* max.((r .- V),0)) .- (beta .* G) # Eq27
                N = N .+ (alpha .* max.(-(r .- V),0)) .- (beta .* N) # Eq 28
            end
            Gtilde = deepcopy(G)
            Ntilde = deepcopy(N)
            Gtilde[allow_idx] = NEGATIVE_Q_VAL
            Ntilde[allow_idx] = -NEGATIVE_Q_VAL
            as = softmax(softmax_beta, a * Gtilde .- b * Ntilde)
            #as = softmax(softmax_beta,Gtilde .- Ntilde)
            #println(a * G .- b * N)
        else
            as = zeros(length(G))
            as[choice_idx] = 1
        end
        if free_choices[i] == "True"
            free_choice_runs +=1
            LL -= log(as[choice_idx])
            #println(record_N_correct)
            if record_N_correct == true
                println(argmax(as), choice_idx)

                if argmax(as) == choice_idx
                    N_correct +=1
                end
            end
        end

    end
    if record_N_correct
        return N_correct / free_choice_runs
    else
        return LL
    end
end



####### Fitting the models, getting parameters and log likelihoods (lls) for all models on the data

rewards = parse.(Int, session_data["outcomes"])
choices = parse.(Int, session_data["choices"])
free_choices = session_data["free_choice"]
allowed_actions = session_data["allowed_actions"]
optimize_mouse_general(Q_learner_ll,[rewards, choices, free_choices, allowed_actions],2)


optimize_mouse_general(Q_learner_ll,[rewards, choices, free_choices, allowed_actions],2)
optimize_mouse_general(Q_learner_decay_ll,[rewards,choices,free_choices,allowed_actions],3)
optimize_mouse_general(Q_learner_port_bias_ll,[rewards,choices,free_choices,allowed_actions],5)
optimize_mouse_general(Q_learner_stickiness_bias_ll,[rewards,choices,free_choices,allowed_actions],3)
optimize_mouse_general(Q_learner_force_free_learning_rate_ll,[rewards,choices,free_choices,allowed_actions],3)
optimize_mouse_general(Q_learner_reward_lr,[rewards, choices, free_choices, allowed_actions],3)
optimize_mouse_general(AU_model_LL,[rewards, choices, free_choices, allowed_actions],5)
# habit model
optimize_mouse_general(Q_learner_habit_model,[rewards, choices, free_choices, allowed_actions],4)

# so for the reversal, significant evidence of a.) stickiness, b.) hugely force free learning rates and c.) less actually of different reward lrs
# interesting as they do appear to treat force and free differently



# compute the log likelihoods of each model across the mouse data
function lls_across_mice(reversal="reversal1_")
    Q_paramss = []
    Q_lls = []
    Q_decay_paramss = []
    Q_decay_lls = []
    Q_port_bias_paramss = []
    Q_port_bias_lls = []
    Q_stickiness_paramss = []
    Q_stickiness_lls = []
    Q_force_free_paramss = []
    Q_force_free_lls = []
    Q_reward_lr_lls = []
    Q_reward_lr_paramss = []
    AU_paramss = []
    AU_lls = []
    habit_paramss = []
    habit_lls = []
    for i in 1:11
        data_idx = i-1
        if reversal == "both"
            println("CONCATTING DATA!")
            session_data = Pickle.load(open("Data_JC04/reversal1_sess_obj_$data_idx"))
            sess_data_initial = Pickle.load(open("Data_JC04/sess_obj_$data_idx"))
            rewards_reversal = parse.(Int, session_data["outcomes"])
            choices_reversal = parse.(Int, session_data["choices"])
            free_choices_reversal = session_data["free_choice"]
            allowed_actions_reversal = session_data["allowed_actions"]
            rewards_initial = parse.(Int, session_data_initial["outcomes"])
            choices_initial = parse.(Int, session_data_initial["choices"])
            free_choices_initial = session_data_initial["free_choice"]
            allowed_actions_initial = session_data_initial["allowed_actions"]
            rewards = vcat(rewards_initial, rewards_reversal)
            choices = vcat(choices_initial, choices_reversal)
            free_choices = vcat(free_choices_initial,free_choices_reversal)
            allowed_actions = vcat(allowed_actions_initial,allowed_actions_reversal)
        else
            session_data = Pickle.load(open("Data_JC04/" * reversal * "sess_obj_$i"))
            rewards = parse.(Int, session_data["outcomes"])
            choices = parse.(Int, session_data["choices"])
            free_choices = session_data["free_choice"]
            allowed_actions = session_data["allowed_actions"]
        end


        Q_params, Q_ll = optimize_mouse_general(Q_learner_ll,[rewards, choices, free_choices, allowed_actions],2)
        Q_decay_params ,Q_decay_ll = optimize_mouse_general(Q_learner_decay_ll,[rewards,choices,free_choices,allowed_actions],3)
        Q_port_bias_params, Q_port_bias_ll = optimize_mouse_general(Q_learner_port_bias_ll,[rewards,choices,free_choices,allowed_actions],5)
        Q_stickiness_params, Q_stickiness_ll = optimize_mouse_general(Q_learner_stickiness_bias_ll,[rewards,choices,free_choices,allowed_actions],3)
        Q_force_free_params, Q_force_free_ll = optimize_mouse_general(Q_learner_force_free_learning_rate_ll,[rewards,choices,free_choices,allowed_actions],3)
        Q_reward_lr_params, Q_reward_lr_ll = optimize_mouse_general(Q_learner_reward_lr,[rewards, choices, free_choices, allowed_actions],3)
        AU_params, AU_ll = optimize_mouse_general(AU_model_LL,[rewards, choices, free_choices, allowed_actions],5)
        habit_params, habit_ll = optimize_mouse_general(Q_learner_habit_model,[rewards, choices, free_choices, allowed_actions],4)

        push!(Q_lls, Q_ll)
        push!(Q_decay_lls, Q_decay_ll)
        push!(Q_port_bias_lls, Q_port_bias_ll)
        push!(Q_stickiness_lls, Q_stickiness_ll)
        push!(Q_force_free_lls, Q_force_free_ll)
        push!(Q_paramss,Q_params)
        push!(Q_stickiness_paramss, Q_stickiness_params)
        push!(Q_force_free_paramss, Q_force_free_params)
        push!(Q_reward_lr_lls, Q_reward_lr_ll)
        push!(Q_reward_lr_paramss, Q_reward_lr_params)
        push!(AU_paramss, AU_params)
        push!(AU_lls, AU_ll)
        push!(habit_paramss, habit_params)
        push!(habit_lls, habit_ll)
    end
    return Q_lls, Q_decay_lls, Q_port_bias_lls, Q_stickiness_lls, Q_force_free_lls, Q_reward_lr_lls, AU_lls,habit_lls,  Q_paramss, Q_stickiness_paramss, Q_force_free_paramss, Q_reward_lr_paramss, AU_paramss, habit_paramss
end

function accuracies_over_mice(reversal = "reversal1_")
    Q_accs = []
    Q_stickiness_accs = []
    Q_force_free_accs = []
    Q_reward_lr_accs = []
    AU_accs = []
    habit_accs = []
    for i in 1:11
        data_idx = i-1
        if reversal == "both"
            println("CONCATTING DATA!")
            session_data = Pickle.load(open("Data_JC04/reversal1_sess_obj_$data_idx"))
            sess_data_initial = Pickle.load(open("Data_JC04/sess_obj_$data_idx"))
            rewards_reversal = parse.(Int, session_data["outcomes"])
            choices_reversal = parse.(Int, session_data["choices"])
            free_choices_reversal = session_data["free_choice"]
            allowed_actions_reversal = session_data["allowed_actions"]
            rewards_initial = parse.(Int, session_data_initial["outcomes"])
            choices_initial = parse.(Int, session_data_initial["choices"])
            free_choices_initial = session_data_initial["free_choice"]
            allowed_actions_initial = session_data_initial["allowed_actions"]
            rewards = vcat(rewards_initial, rewards_reversal)
            choices = vcat(choices_initial, choices_reversal)
            free_choices = vcat(free_choices_initial,free_choices_reversal)
            allowed_actions = vcat(allowed_actions_initial,allowed_actions_reversal)
        else
            session_data = Pickle.load(open("Data_JC04/" * reversal * "sess_obj_$i"))
            rewards = parse.(Int, session_data["outcomes"])
            choices = parse.(Int, session_data["choices"])
            free_choices = session_data["free_choice"]
            allowed_actions = session_data["allowed_actions"]
        end
        # compute optimal params
        Q_params, Q_ll = optimize_mouse_general(Q_learner_ll,[rewards, choices, free_choices, allowed_actions],2)
        Q_stickiness_params, Q_stickiness_ll = optimize_mouse_general(Q_learner_stickiness_bias_ll,[rewards,choices,free_choices,allowed_actions],3)
        Q_force_free_params, Q_force_free_ll = optimize_mouse_general(Q_learner_force_free_learning_rate_ll,[rewards,choices,free_choices,allowed_actions],3)
        Q_reward_lr_params, Q_reward_lr_ll = optimize_mouse_general(Q_learner_reward_lr,[rewards, choices, free_choices, allowed_actions],3)
        AU_params, AU_ll = optimize_mouse_general(AU_model_LL,[rewards, choices, free_choices, allowed_actions],4)
        habit_params, habit_ll = optimize_mouse_general(Q_learner_habit_model,[rewards, choices, free_choices, allowed_actions],4)

        #compute accs
        Q_acc = Q_learner_ll(rewards, choices, free_choices, allowed_actions, Q_params[1],Q_params[2],false,true)
        Q_stickiness_acc = Q_learner_stickiness_bias_ll(rewards, choices, free_choices, allowed_actions, Q_stickiness_params[1],Q_stickiness_params[2],Q_stickiness_params[3],false, true)
        Q_force_free_acc = Q_learner_force_free_learning_rate_ll(rewards, choices, free_choices, allowed_actions, Q_force_free_params[1],Q_force_free_params[2],Q_force_free_params[3], false,true)
        Q_reward_lr_acc = Q_learner_reward_lr(rewards, choices, free_choices, allowed_actions,Q_reward_lr_params[1], Q_reward_lr_params[2], Q_reward_lr_params[3],false, true)
        AU_acc = AU_model_LL(rewards, choices, free_choices,allowed_actions, AU_params[1], AU_params[2], AU_params[3], AU_params[4], true)
        habit_acc = Q_learner_habit_model(rewards, choices, free_choices, allowed_actions, habit_params[1], habit_params[2], habit_params[3], habit_params[4], false, true)
        push!(Q_accs, Q_acc)
        push!(Q_stickiness_accs,Q_stickiness_acc)
        push!(Q_force_free_accs, Q_force_free_acc)
        push!(Q_reward_lr_accs, Q_reward_lr_acc)
        push!(AU_accs, AU_acc)
        push!(habit_accs, habit_acc)
    end
    return Q_accs, Q_stickiness_accs, Q_force_free_accs,Q_reward_lr_accs, AU_accs, habit_accs
end



### Analyse mouse data

Q_accs, Q_stickiness_accs, Q_force_free_accs,Q_reward_lr_accs,AU_accs, habit_accs = accuracies_over_mice("both")


subject_IDs = ["A3.6b", "D4.4c", "D3.3d", "D4.4g", "A3.6a", "D3.3b", "D3.5b", "D3.5d", "D4.4b", "A3.5a", "A3.6d"]
length(subject_IDs)
length(Q_accs)
bar(subject_IDs, Q_accs, label="")
xlabel!("Subject ID")
ylabel!("Accuracy")
title!("Q learning accuracies")
savefig("Q_learning_accuracy_across_mice_both.png")


bar(subject_IDs, Q_stickiness_accs, label="")
xlabel!("Subject ID")
ylabel!("Accuracy")
title!("Q Stickiness Accuracies")
savefig("Q_stickiness_accuracy_across_mice_both.png")

bar(subject_IDs, Q_force_free_accs, label="")
xlabel!("Subject ID")
ylabel!("Accuracy")
title!("Q force-free Accuracies")
savefig("Q_force_free_accuracy_across_mice_both.png")

bar(subject_IDs, Q_reward_lr_accs, label="")
xlabel!("Subject ID")
ylabel!("Accuracy")
title!("Q Reward LR Accuracies")
savefig("Q_reward_lr_accuracy_across_mice_both.png")

subject_IDs = ["A3.6b", "D4.4c", "D3.3d", "D4.4g", "A3.6a", "D3.3b", "D3.5b", "D3.5d", "D4.4b", "A3.5a", "A3.6d"]
length(subject_IDs)
length(AU_accs)
bar(subject_IDs, AU_accs, label="")
xlabel!("Subject ID")
ylabel!("Accuracy")
title!("Mikhael Model Accuracy")
savefig("AU_accuracy_across_mice_both.png")

# habit model
subject_IDs = ["A3.6b", "D4.4c", "D3.3d", "D4.4g", "A3.6a", "D3.3b", "D3.5b", "D3.5d", "D4.4b", "A3.5a", "A3.6d"]
length(subject_IDs)
length(habit_accs)
bar(subject_IDs, habit_accs, label="")
xlabel!("Subject ID")
ylabel!("Accuracy")
title!("Habit Model Accuracy")
savefig("habit_model_accuracy_across_mice_both.png")


# plot accuracy bar graph
mean_Q_acc = mean(Q_accs)
std_Q_acc = std(Q_accs) / 10
mean_Q_stickiness = mean(Q_stickiness_accs)
std_Q_stickiness = std(Q_stickiness_accs) / 10
mean_Q_force_free = mean(Q_force_free_accs)
std_Q_force_free = std(Q_force_free_accs) / 10
mean_Q_reward_lr = mean(Q_reward_lr_accs)
std_Q_reward_lr = std(Q_reward_lr_accs) / 10
mean_AU_acc = mean(AU_accs)
std_AU_acc = std(AU_accs) / 10
mean_habit_acc = mean(habit_accs)
std_habit_acc = std(habit_accs) / 10

#alg_labels = ["Q_learning","stickiness","force-free", "reward-lr","Go-NoGo model", "Habit Model"]
#mean_accs = [mean_Q_acc, mean_Q_stickiness, mean_Q_force_free, mean_Q_reward_lr, mean_AU_acc, mean_habit_acc]
#accs_std = [std_Q_acc, std_Q_stickiness, std_Q_force_free, std_Q_reward_lr,std_AU_acc, std_habit_acc]

alg_labels = ["Q_learning","stickiness","force-free", "reward-lr", "Habit Model"]
mean_accs = [mean_Q_acc, mean_Q_stickiness, mean_Q_force_free, mean_Q_reward_lr, mean_habit_acc]
accs_std = [std_Q_acc, std_Q_stickiness, std_Q_force_free, std_Q_reward_lr, std_habit_acc]

bar(alg_labels, mean_accs, yerr=accs_std,label="")
xlabel!("Algorithm")
ylabel!("Mean Accuracy")
title!("Fitted Accuracy by Model")
savefig("both_Algorithm_accuracy_comparison_3.png")


Q_lls, Q_decay_lls, Q_port_bias_lls, Q_stickiness_lls, Q_force_free_lls,Q_reward_lr_lls,AU_lls, habit_lls, Q_paramss, Q_stickiness_paramss, Q_force_free_paramss, Q_reward_lr_paramss,AU_paramss, habit_accs  = lls_across_mice("both")
mean_Q_lls = mean(Q_lls)
std_Q_lls = std(Q_lls) / 10
mean_Q_decay_lls = mean(Q_decay_lls)
std_Q_decay_lls = std(Q_decay_lls) / 10
mean_Q_port_bias_lls = mean(Q_port_bias_lls)
std_Q_port_bias_lls = std(Q_port_bias_lls) / 10
mean_Q_stickiness_lls = mean(Q_stickiness_lls)
std_Q_stickiness_lls = std(Q_stickiness_lls) / 10
mean_Q_force_free_lls = mean(Q_force_free_lls)
std_Q_force_free_lls = std(Q_force_free_lls) / 10
mean_Q_reward_lr_lls = mean(Q_reward_lr_lls)
std_Q_reward_lr_lls = std(Q_reward_lr_lls) / 10
mean_AU_lls = mean(AU_lls)
std_AU_lls = std(AU_lls) / 10
mean_habit_lls = mean(habit_lls)
std_habit_lls = std(habit_lls) / 10


hcat(Q_reward_lr_paramss...)

#alg_labels = ["Q_learning","decay","side_bias","stickiness","force-free", "reward-lr","Go-NoGo", "Habit Model"]
#mean_lls = [mean_Q_lls, mean_Q_decay_lls, mean_Q_port_bias_lls, mean_Q_stickiness_lls, mean_Q_force_free_lls, mean_Q_reward_lr_lls, mean_AU_lls, mean_habit_lls]
#stds = [std_Q_lls,std_Q_decay_lls, std_Q_port_bias_lls, std_Q_stickiness_lls, std_Q_force_free_lls,std_Q_reward_lr_lls, std_AU_lls, std_habit_lls]

alg_labels = ["Q_learning","decay","side_bias","stickiness","force-free", "reward-lr", "Habit Model"]
mean_lls = [mean_Q_lls, mean_Q_decay_lls, mean_Q_port_bias_lls, mean_Q_stickiness_lls, mean_Q_force_free_lls, mean_Q_reward_lr_lls, mean_habit_lls]
stds = [std_Q_lls,std_Q_decay_lls, std_Q_port_bias_lls, std_Q_stickiness_lls, std_Q_force_free_lls,std_Q_reward_lr_lls, std_habit_lls]

bar(alg_labels, mean_lls, yerr=stds,label="")
xlabel!("Algorithm")
ylabel!("NLL")
title!("NLL across models")
savefig("both_NLL_comparisons_4.png")

Q_paramss_comb = hcat(Q_paramss...)
Q_params_means = mean(Q_paramss_comb,dims=2)
Q_params_stds = std(Q_paramss_comb, dims=2)

Q_param_labels = ["learning_rate","softmax beta"]
bar(Q_param_labels, Q_params_means, yerr=Q_params_stds, label="")
xlabel!("Parama")

function count_choices(choices)
    choice_array = [0,0,0]
    for c in choices
        choice_array[c] +=1
    end
    return choice_array
end

count_choices(choices)
session_data = Pickle.load(open("Data_JC04/reversal1_sess_obj_10"))
rewards = parse.(Int, session_data["outcomes"])
choices = parse.(Int, session_data["choices"])
free_choices = session_data["free_choice"]
allowed_actions = session_data["allowed_actions"]


stored_probas = parse.(Float64, session_data["store_probas"])
moving_average(vs,n) = [sum(@view vs[i:(i+n-1)])/n for i in 1:(length(vs)-(n-1))]
moving_average(rewards, 20)
plot(moving_average(rewards,20))
plot(choices)
session_data["store_probas"]
parse.(Float64,session_data["choices"])
session_data["trial_types"]
session_data["choices"]
session_data["allowed_actions"]
free_choices
# get free choice rewards
free_choice_rewards = [rewards[i]  for i in 1:length(rewards) if free_choices[i] == "True"]
plot(moving_average(free_choice_rewards, 20))
allowed_actions[100].splits("-")
split(allowed_actions[100],"-")

function compute_correct_choices(choices, allowed_actions, free_choices, stored_probas)
    correct_choices = []
    direction_dict = Dict("L" => 1, "U"=>2, "R"=>3)
    for (i,choice) in enumerate(choices)
        # only allow free choices
        if free_choices[i] == "True"
            if allowed_actions[i] != "None"
                allowed_action1,allowed_actions2 = split(allowed_actions[i],"-")
                idx_1 = direction_dict[allowed_action1]
                idx_2 = direction_dict[allowed_actions2]
                proba1 = stored_probas[idx_1]
                proba2 = stored_probas[idx_2]
                if proba1 > proba2
                    correct_idx = idx_1
                else
                    correct_idx = idx_2
                end
                if choices[i] == correct_idx
                    push!(correct_choices, 1)
                else
                    push!(correct_choices, 0)
                end
            end
        end
    end
    return correct_choices
end


correct_choices = compute_correct_choices(choices, allowed_actions, free_choices,stored_probas)
plot(moving_average(correct_choices, 20))

# this function just does some visualization of waht the actual correct choices are
function plot_correct_choices_for_each_animal(moving_average_N=100)
    p = plot()
    for i in 1:10
        session_data = Pickle.load(open("Data_JC04/reversal1_sess_obj_$i"))
        rewards = parse.(Int, session_data["outcomes"])
        choices = parse.(Int, session_data["choices"])
        free_choices = session_data["free_choice"]
        allowed_actions = session_data["allowed_actions"]
        stored_probas = parse.(Float64, session_data["store_probas"])
        correct_choices = compute_correct_choices(choices, allowed_actions, free_choices,stored_probas)
        plot!(moving_average(correct_choices, moving_average_N),label=subject_IDs[i])
    end
    xlabel!("Episode")
    ylabel!("Average correct choice")
    title!("Correct choices per mouse")
    savefig("Correct_choices_after_reversal_per_mouse_"*string(moving_average_N)*".png")
    display(p)
end
plot_correct_choices_for_each_animal(100)

hcat(Q_force_free_paramss...)


ff_params = hcat(Q_force_free_paramss...)
length(ff_params[1,:])
interleaved_params = []
for i in 1:10
    push!(interleaved_params, ff_params[1,i])
end
for i in 1:10
    push!(interleaved_params, ff_params[2,i])
end
sx = repeat(["lr_free","lr_fixed"], inner=10)
parse.(Float64,interleaved_params)
labels = repeat(subject_IDs[1:end-1], outer=2)
groupedbar(labels, parse(interleaved_params, group = sx, ylabel = "Param Value",
        title = "Free and Fixed Learning rate", bar_width = 0.67,xlabel="Subject ID")

