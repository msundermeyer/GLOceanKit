%
%
%   modes = InternalModes(rho,z,z_out,latitude)
%   'rho' must be a vector with length matching 'z'. For finite
%   differencing, z_out is determined with interpolation, with spectral
%   methods, it is projected onto the output grid.
%
%   modes = InternalModes(rho,z_domain,z_out,latitude)
%   'rho' must be a function handle. z_domain must be an array with two
%   values: z_domain = [z_bottom z_surface];
%
classdef InternalModesBase < handle
    properties (Access = public)
        % scalar constants
        latitude
        f0
        Lz
        rho0
        
        % output dimension (and grid), and variables on that grid.
        z
        rho
        N2
        
        normalization = 'const_G_norm'
        upper_boundary = 'rigid_lid'
        method = 'scaled_spectral'
        
        % This should be added *only* to the FiniteDifference subclass, but
        % it needs to be added here because of Matlab's fail obj-oriented
        % class system. Sad!
        orderOfAccuracy
    end
    
    properties (Dependent)
       rho_z
       rho_zz
    end
    
    properties (Access = protected)
        g = 9.81
    end
    
    methods
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        % Initialization
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function self = InternalModesBase(rho, z_in, z_out, latitude, orderOfAccuracy)
            % This should be in the subclass, but we include it here as a
            % workaround.
            if nargin < 5
                orderOfAccuracy = 4;
            end
            
            self.Lz = max(z_in) - min(z_in);
            self.latitude = latitude;
            self.f0 = 2*(7.2921e-5)*sin(latitude*pi/180);
            self.orderOfAccuracy = orderOfAccuracy;
            
            % Make everything a column vector
            if isrow(z_in)
                z_in = z_in.';
            end
            if isrow(z_out)
                z_out = z_out.';
            end
             
            % Is density specified as a function handle or as a grid of
            % values?
            if isa(rho,'function_handle') == true
                if numel(z_in) ~= 2
                    error('When using a function handle, z_domain must be an array with two values: z_domain = [z_bottom z_surface];')
                end
                self.rho0 = rho(max(z_in));
                self.InitializeWithFunction(rho, min(z_in), max(z_in), z_out)
            elseif isa(rho,'numeric') == true
                if numel(rho) ~= length(rho) || length(rho) ~= length(z_in)
                    error('rho must be 1 dimensional and z must have the same length');
                end
                if isrow(rho)
                    rho = rho.';
                end
                self.rho0 = min(rho);
                self.InitializeWithGrid(rho,z_in);
            else
                error('rho must be a function handle or an array.');
            end
            

            
%             if nargin == 4
%                 if  (~strcmp(method, 'scaled_spectral') && ~strcmp(method, 'finite_difference') && ~strcmp(method, 'spectral'))
%                     error('Invalid method!')
%                 else
%                     obj.method = method;
%                 end
%             end
            
        end
        
        function self = InitializeWithGrid(self, rho, z_in)
        end
        
        function self = InitializeWithFunction(self, rho, z_min, z_max, z_out)
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        % Set the normalization and upper boundary condition
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function set.normalization(obj,norm)
            if  (~strcmp(norm, 'max_u') && ~strcmp(norm, 'max_w') && ~strcmp(norm, 'const_G_norm') && ~strcmp(norm, 'const_F_norm'))
                error('Invalid normalization!')
            else
                obj.normalization = norm;
            end
        end
        
        function set.upper_boundary(obj,upper_boundary)
            if  (~strcmp(upper_boundary, 'free_surface') && ~strcmp(upper_boundary, 'rigid_lid') )
                error('Invalid upper boundary condition!')
            else
                obj.upper_boundary = upper_boundary;
            end
        end
        
        function value = get.rho_z(self)
            value = zeros(size(self.z));
        end
        
        function obj = ModesAtWavenumber(obj, k )
            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        % Generical function to normalize
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [F,G] = NormalizeModes(self,F,G,z)
            [~,maxIndexZ] = max(z);
            for j=1:length(G(1,:))
                if strcmp(self.normalization, 'max_u')
                    A = max( abs(F(:,j)) );
                    G(:,j) = G(:,j) / A;
                    F(:,j) = F(:,j) / A;
                elseif strcmp(self.normalization, 'max_w')
                    A = max( abs(G(:,j)) );
                    G(:,j) = G(:,j) / A;
                    F(:,j) = F(:,j) / A;
                elseif strcmp(self.normalization, 'const_G_norm')
                    A = trapz( z, (1/self.g) * (self.N2 - self.f0*self.f0) .* G(:,j) .^ 2);
                    G(:,j) = G(:,j) / sqrt(A);
                    F(:,j) = F(:,j) / sqrt(A);
                elseif strcmp(self.normalizationnorm, 'const_F_norm')
                    A = abs(trapz( z_out, (1/abs(z(end)-z(1))) .* F(:,j) .^ 2));
                    G(:,j) = G(:,j) / sqrt(A);
                    F(:,j) = F(:,j) / sqrt(A);
                end
                
                if F(maxIndexZ,j)< 0
                    F(:,j) = -F(:,j);
                    G(:,j) = -G(:,j);
                end
            end
        end
        
    end
end

