classdef InternalModesFiniteDifference < InternalModesBase
    % This class uses finite differencing of arbitrary order to compute the
    % internal wave modes. See InternalModesBase f
    properties (Access = public)
        rho  % Density on the z grid.
        N2 % Buoyancy frequency on the z grid, $N^2 = -\frac{g}{\rho(0)} \frac{\partial \rho}{\partial z}$.
        orderOfAccuracy = 4 % Order of accuracy of the finite difference matrices.
    end
    
    properties (Dependent)
        rho_z % First derivative of density on the z grid.
        rho_zz % Second derivative of density on the z grid.
    end
    
    properties (Access = private)
        n                   % length of z_diff
        z_diff              % the z-grid used for differentiation
        rho_z_diff          % rho on the z_diff grid
        N2_z_diff           % N2 on the z_diff grid
        Diff1               % 1st derivative matrix, w/ 1st derivative boundaries
        Diff2               % 2nd derivative matrix, w/ BCs set by upperBoundary property
        
        T_out               % *function* handle that transforms from z_diff functions to z_out functions
    end
    
    methods
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        % Initialization
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function self = InternalModesFiniteDifference(rho, z_in, z_out, latitude, varargin)
            % Initialize with either a grid or analytical profile.
            self@InternalModesBase(rho,z_in,z_out,latitude,varargin{:});
            
            self.n = length(self.z_diff);
            self.Diff1 = InternalModesFiniteDifference.FiniteDifferenceMatrix(1, self.z_diff, 1, 1, self.orderOfAccuracy);
            self.N2_z_diff = -(self.g/self.rho0) * self.Diff1 * self.rho_z_diff;
            self.upperBoundaryDidChange(); % this sets Diff2          
            
            self.InitializeOutputTransformation(z_out);
            self.rho = self.T_out(self.rho_z_diff);
            self.N2 = self.T_out(self.N2_z_diff);
            
            if isempty(self.nModes) || self.nModes < 1
                self.nModes = self.n;
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        % Computation of the modes
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [F,G,h] = ModesAtWavenumber(self, k )
            % Return the normal modes and eigenvalue at a given wavenumber.
            
            % The eigenvalue equation is,
            % G_{zz} - K^2 G = \frac{f_0^2 -N^2}{gh_j}G
            % A = \left( \partial_{zz} - K^2*I \right)
            % B = \frac{f_0^2 - N^2}{g}
            A = self.Diff2 - k*k*eye(self.n);
            B = diag(self.f0*self.f0 - self.N2_z_diff)/self.g;
            
            % Bottom boundary condition (always taken to be G=0)
            % NOTE: we already chose the correct BCs when creating the
            % Diff2 matrix
            A(1,:) = self.Diff2(1,:);
            B(1,:) = 0;
            
            % Surface boundary condition
            A(end,:) = self.Diff2(end,:);
            if strcmp(self.upperBoundary, 'free_surface')
                % G_z = \frac{1}{h_j} G at the surface
                B(end,end)=1;
            elseif strcmp(self.upperBoundary, 'rigid_lid')
                % G=0 at the surface (note we chose this BC when creating Diff2)
                B(end,end)=0;
            end
            
            h_func = @(lambda) 1.0 ./ lambda;
            [F,G,h] = ModesFromGEP(self,A,B,h_func);
        end
        
        function [F,G,h] = ModesAtFrequency(self, omega )
            % Return the normal modes and eigenvalue at a given frequency.
            
            A = self.Diff2;
            B = -diag(self.N2_z_diff - omega*omega)/self.g;
            
            % Bottom boundary condition (always taken to be G=0)
            % NOTE: we already chose the correct BCs when creating the
            % Diff2 matrix
            A(1,:) = self.Diff2(1,:);
            B(1,:) = 0;
            
            % Surface boundary condition
            if strcmp(self.upperBoundary, 'free_surface')
                % G_z = \frac{1}{h_j} G at the surface
                B(end,end)=1;
            elseif strcmp(self.upperBoundary, 'rigid_lid')
                % G=0 at the surface (note we chose this BC when creating Diff2)
                A(end,:) = self.Diff2(end,:);
                B(end,end)=0;
            end
            
            h_func = @(lambda) 1.0 ./ lambda;
            [F,G,h] = ModesFromGEP(self,A,B,h_func);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        % Computed (dependent) properties
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function value = get.rho_z(self)
            value = self.Diff1 * self.rho_z_diff;
        end
        
        function value = get.rho_zz(self)
            diff2 = InternalModesFiniteDifference.FiniteDifferenceMatrix(2, self.z_diff, 2, 2, self.orderOfAccuracy);
            value = diff2 * self.rho_z_diff;
        end
    end
    
    methods (Access = protected)     
        function self = InitializeWithGrid(self, rho, z_in)
            % Used internally by subclasses to intialize with a density function.
            %
            % Superclass calls this method upon initialization when it
            % determines that the input is given in gridded form. The goal
            % is to initialize z_diff and rho_z_diff.
            self.z_diff = z_in;
            self.rho_z_diff = rho;
        end

        function self = InitializeWithFunction(self, rho, z_min, z_max, z_out)
            % Used internally by subclasses to intialize with a density grid.
            %
            % The superclass calls this method upon initialization when it
            % determines that the input is given in functional form. The
            % goal is to initialize z_diff and rho_z_diff.
            if length(z_out) < 5
                error('You need more than 5 point output points for finite differencing to work');
            end
            
            if (min(z_out) == z_min && max(z_out) == z_max)
                self.z_diff = z_out;
                self.rho_z_diff = rho(self.z_diff);
            else
                error('Other cases not yet implemented');
                % Eventually we may want to use stretched coordinates as a
                % default
            end
        end
        
        function self = upperBoundaryDidChange(self)
            % This function is called when the user changes the surface
            % boundary condition. By overriding this function, a subclass
            % can respond as necessary.
            if strcmp(self.upperBoundary, 'free_surface')
                rightBCDerivs = 1;
            else
                rightBCDerivs = 0;
            end
            self.Diff2 = InternalModesFiniteDifference.FiniteDifferenceMatrix(2, self.z_diff, 0, rightBCDerivs, self.orderOfAccuracy);
        end

    end
    
    methods (Access = private)   
        function self = InitializeOutputTransformation(self, z_out)
            % After the input variables have been initialized, this is used to
            % initialize the output transformation, T_out(f).            
            if isequal(self.z_diff,z_out)
                self.T_out = @(f_in) real(f_in);
            else % want to interpolate onto the output grid
                self.T_out = @(f_in) interp1(self.z_diff,real(f_in),z_out);
            end
        end
        

        function [F,G,h] = ModesFromGEP(self,A,B,h_func)
            % Take matrices A and B from the generalized eigenvalue problem
            % (GEP) and returns F,G,h. The h_func parameter is a function that
            % returns the eigendepth, h, given eigenvalue lambda from the GEP.
            [V,D] = eig( A, B );
            
            [lambda, permutation] = sort(real(diag(D)),1,'ascend');
            G = V(:,permutation);
            h = h_func(lambda.');
            
            F = zeros(self.n,self.n);
            for j=1:self.n
                F(:,j) = h(j) * self.Diff1 * G(:,j);
            end
            
            [F_norm,G_norm] = self.NormalizeModes(F,G,self.N2_z_diff, self.z_diff);
            
            F = zeros(length(self.z),self.nModes);
            G = zeros(length(self.z),self.nModes);
            for iMode=1:self.nModes
                F(:,iMode) = self.T_out(F_norm(:,iMode));
                G(:,iMode) = self.T_out(G_norm(:,iMode));
            end
            h = h(1:self.nModes);
        end
    end
    
    methods (Static)
        function D = FiniteDifferenceMatrix(numDerivs, x, leftBCDerivs, rightBCDerivs, orderOfAccuracy)
            % Creates a finite difference matrix of aribtrary accuracy, on an arbitrary
            % grid. Left and right boundary conditions are specified as their order of
            % derivative.
            %
            % numDerivs ? the number of derivatives
            % x ? the grid
            % leftBCDerivs ? derivatives for the left boundary condition.
            % rightBCDerivs ? derivatives for the right boundary condition.
            % orderOfAccuracy ? minimum order of accuracy required
            %
            % Jeffrey J. Early, 2015
            
            n = length(x);
            D = zeros(n,n);
            
            % left boundary condition
            range = 1:(orderOfAccuracy+leftBCDerivs); % not +1 because we're computing inclusive
            c = InternalModesFiniteDifference.weights( x(1), x(range), leftBCDerivs );
            D(1,range) = c(leftBCDerivs+1,:);
            
            % central derivatives, including possible weird end points
            centralBandwidth = ceil(numDerivs/2)+ceil(orderOfAccuracy/2)-1;
            for i=2:(n-1)
                rangeLength = 2*centralBandwidth; % not +1 because we're computing inclusive
                startIndex = max(i-centralBandwidth, 1);
                endIndex = startIndex+rangeLength;
                if (endIndex > n)
                    endIndex = n;
                    startIndex = endIndex-rangeLength;
                end
                range = startIndex:endIndex;
                c = InternalModesFiniteDifference.weights( x(i), x(range), numDerivs );
                D(i,range) = c(numDerivs+1,:);
            end
            
            % right boundary condition
            range = (n-(orderOfAccuracy+rightBCDerivs-1)):n; % not +1 because we're computing inclusive
            c = InternalModesFiniteDifference.weights( x(n), x(range), rightBCDerivs );
            D(n,range) = c(rightBCDerivs+1,:);
        end
        
        function c = weights(z,x,m)
            % Calculates FD weights. The parameters are:
            %  z   location where approximations are to be accurate,
            %  x   vector with x-coordinates for grid points,
            %  m   highest derivative that we want to find weights for
            %  c   array size m+1,lentgh(x) containing (as output) in
            %      successive rows the weights for derivatives 0,1,...,m.
            %
            % Taken from Bengt Fornberg
            %
            n=length(x); c=zeros(m+1,n); c1=1; c4=x(1)-z; c(1,1)=1;
            for i=2:n
                mn=min(i,m+1); c2=1; c5=c4; c4=x(i)-z;
                for j=1:i-1
                    c3=x(i)-x(j);  c2=c2*c3;
                    if j==i-1
                        c(2:mn,i)=c1*((1:mn-1)'.*c(1:mn-1,i-1)-c5*c(2:mn,i-1))/c2;
                        c(1,i)=-c1*c5*c(1,i-1)/c2;
                    end
                    c(2:mn,j)=(c4*c(2:mn,j)-(1:mn-1)'.*c(1:mn-1,j))/c3;
                    c(1,j)=c4*c(1,j)/c3;
                end
                c1=c2;
            end
            
        end
    end
    
end

