%MDL_QUADCOPTER Dynamic parameters for a quadrotor.
%
% MDL_QUADCOPTER is a script creates the workspace variable quad which
% describes the dynamic characterstics of a quadrotor flying robot.
%
% Properties::
%
% This is a structure with the following elements:
%
% nrotors   Number of rotors (1x1)
% g         Gravity
% M         Mass (1x1)
% J         Flyer rotational inertia matrix (3x3)

quadrotor.nrotors = 4;                %   4 rotors
quadrotor.g = 9.80665;                   %   g       Gravity                             1x1


% Airframe
quadrotor.M = 2.5;                      %   M       Mass                                1x1
quadrotor.Ixx = 0.064;
quadrotor.Iyy = 0.064;
quadrotor.Izz = 0.112;
quadrotor.J = diag([quadrotor.Ixx quadrotor.Iyy quadrotor.Izz]);    %   I       Flyer rotational inertia matrix     3x3

quadrotor.h = -0.007;                 %   h       Height of rotors above CoG          1x1
quadrotor.d = 0.315;                  %   d       Length of flyer arms                1x1

%Rotor
quadrotor.r = 0.165;                  %   r       Rotor radius                        1x1
