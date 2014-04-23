function lqr_traj = lqr_backups_for_trajectory_following(nom_traj, target_traj, simulate_f, model, idx, model_bias, ...
	reward, magic_factor)

     % Authors: Pieter Abbeel (pabbeel@cs.berkeley.edu)
     %          Adam Coates (acoates@cs.stanford.edu)

% nom_traj: we linearize around this traj
% target_traj: this is our target
% simulate_f: function that we can call as follows: next_state =
%            simulate_f(current_state, inputs, simtime, params, model_bias)
% model: parameters and features of the dynamics model (simulate_f)
% idx: how we index into features and state using named indexes
% model_bias: offsets we use for the model at each time slice
% reward
% magic_factor: how much the dynamics is altered to automatically reach the
% target

state_multipliers = reward.state_multipliers;
input_multipliers = reward.input_multipliers;
%linear_terms_state = reward.linear_terms_state;

H = size(target_traj.x, 1);
dim_x =length(state_multipliers);
dim_u = length(input_multipliers);

% state is augmented with inputs from past 2 timesteps, so state vector
% actually of length dim_x + 2*dim_u

if( dim_x ~= size(nom_traj.x,2) | dim_x ~= size(target_traj.x,2) ...
		| dim_u ~= size(nom_traj.u,2) | dim_u ~= size(target_traj.u,2) ...
		| H ~= size(nom_traj.x,1) | H ~= size(target_traj.x,1) ...
		| H ~= size(nom_traj.u,1) | H ~= size(target_traj.u,1) ...
		| H ~= length(nom_traj.t) | H ~= length(target_traj.t) )
	fprintf(1, 'dimension mismatch for inputs to lqr_trajectory(...)\n');
	nom_traj
	target_traj
	whos state_multipliers input_multipliers
end

% no need for action deltas anymore, we use change in actions as inputs
%Qaction_delta = [zeros(1,dim_x) 1 -1 0 0 0]'*[zeros(1,dim_x) 1 -1 0 0 0]*action_deltas(1) + ..
%	[zeros(1,dim_x) 0 0 1 -1 0]'*[zeros(1,dim_x) 0 0 1 -1 0]*action_deltas(2);

Qf = diag([state_multipliers]);
%Qf(:,end) = .5*linear_terms_state;
%Qf(end,:) = .5*linear_terms_state;

Rf = diag(input_multipliers);

Ps = Qf;

lqr_traj.t = nom_traj.t;

for i=H-1:-1:1
	DT_control = lqr_traj.t(i+1)-lqr_traj.t(i);
	[A, B] = linearized_dynamics(nom_traj.x(i,:)', nom_traj.u(i,:)', ...
		target_traj.x(i,:)', target_traj.x(i+1,:)', ...
		simulate_f, DT_control, model, idx, model_bias(i,:)', magic_factor, target_traj.x(i+1,:)');
	Q = diag([state_multipliers]);
	%Q(:,end) = .5*linear_terms_state;
	%Q(end,:) = .5*linear_terms_state;
	R = diag(input_multipliers);

	Q = Q*DT_control;
	R = R*DT_control;
    K = -pinv(R + B'*Ps*B) * B' * Ps * A;
    tmp = A+B*K;
    Ps = Q + K'*R*K + tmp'*Ps*tmp;

    lqr_traj.K{i} = K;
    %% add nominal inputs to offset term in K
    
    lqr_traj.target_x(i,:) = target_traj.x(i,:);
	lqr_traj.target_u(i,:) = target_traj.u(i,:);
    lqr_traj.A{i} = A;
    lqr_traj.B{i} = B;
    lqr_traj.Q{i} = Q;
    lqr_traj.R{i} = R;
end
lqr_traj.target_x(H,:) = target_traj.x(H,:);
lqr_traj.target_u(H,:) = target_traj.u(H,:);
lqr_traj.Q{H} = Qf;
lqr_traj.R{H} = Rf;
lqr_traj.nom_x = nom_traj.x;
lqr_traj.nom_u = nom_traj.u;


